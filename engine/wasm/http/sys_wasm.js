// Launcher program for web browser and .wasm builds
let isStreaming = false

function initWasm(bytes) {
  let libraries = {
    env: Q3e,
    SYS: SYS,
    GL: EMGL,
    MATH: MATHS,
    FS: FS,
    NET: NET,
    DATE: DATE,
    INPUT: INPUT,
    STD: STD,
  }
  let viewport = document.getElementById('viewport-frame')
  Q3e['canvas'] = viewport.getElementsByTagName('CANVAS')[0]
  if(!bytes) {
    if(Q3e.canvas) {
      Q3e.canvas.transferControlToOffscreen()
    }
    // try it in a service worker
    if((window.location.protocol == 'http:' 
      || window.location.protocol == 'https:'
      || window.location.protocol == 'chrome-extension:')
      && 'serviceWorker' in navigator) {
      navigator.serviceWorker.register('quake3e.js', { scope: '/' })
        .then(function (registration) {
          if(typeof SYS != 'undefined') SYS.servicable = true
        })
        .catch(function (err) {
          if(typeof SYS != 'undefined') SYS.servicable = false
          console.log('Service Worker registration failed: ', err)
        })
    }
    document.body.classList.add('no-gl')
    throw new Error('Couldn\'t find wasm!')
  }

  // assign everything to env because this bullshit don't work
  Object.assign(Q3e, libraries)
  for(let i = 0; i < Object.keys(libraries).length; i++) {
    Object.assign(Q3e.env, Object.values(libraries)[i])
  }

  if(isStreaming) {
    return WebAssembly.instantiateStreaming(bytes, Q3e)
  } else {
    return WebAssembly.instantiate(bytes, Q3e)
  }
}

function _base64ToArrayBuffer(base64) {
  var binary_string = window.atob(base64);
  var len = binary_string.length;
  var bytes = new Uint8Array(len);
  for (var i = 0; i < len; i++) {
      bytes[i] = binary_string.charCodeAt(i);
  }
  return bytes;
}

function init() {
  window.Module = Q3e
  Q3e['imports'] = Q3e
  // might as well start this early, transfer IndexedDB from disk/memory to application memory
  Q3e['cacheBuster'] = Date.now()
  Q3e['table'] = Q3e['__indirect_function_table'] =
    new WebAssembly.Table({ initial: 1000, element: 'anyfunc', maximum: 10000 })
  Q3e['memory'] = new WebAssembly.Memory({ 'initial': 2048, /* 'shared': true */ })
  updateGlobalBufferAndViews(Q3e.memory.buffer)

  // load IndexedDB
  readAll()

  // TODO: offline download so it saves binary to IndexedDB
  if(typeof window.preFS != 'undefined') {
    let preloadedPaths = Object.keys(window.preFS)
    for(let i = 0; i < preloadedPaths.length; i++) {

      FS.virtual[preloadedPaths[i]] = {
        timestamp: new Date(),
        mode: FS_FILE,
        contents: _base64ToArrayBuffer(window.preFS[preloadedPaths[i]])
      }
    }

    if(typeof FS.virtual['quake3e.wasm'] != 'undefined') {
      return new Promise(function(resolve) {
        setTimeout(function () {
          resolve(FS.virtual['quake3e.wasm'].contents)
        }, 600)
      })
    }
  }

  //isStreaming = true
  //return fetch('./quake3e.wasm?time=' + Q3e.cacheBuster)
  //  .catch(function (e) {})
  return Promise.resolve()
}

// TODO: change when hot reloading works
window.addEventListener('load', function () {
  if(typeof Q3e.imports == 'undefined') {
    if(!typeof window.initAce != 'undefined') {
      initAce()
    }
    init()
    .then(initWasm)
    .then(initEngine);
  }
}, false)
