
const LONG_LOOPS = 10000


async function runLoop(init, test, update, body, runContext) {
	let result
	if(body.type != 'BlockStatement') {
		throw new Error('ForStatement: Not implemented!')
	}
	let initAndTest = await runThisAndThat(init, test, runContext)
	if(!isStillRunning(runContext)) {
		return
	}

	let testResults = initAndTest[1]
	// TODO: turn off safety feature with an attribute @LongLoops
	let safety = LONG_LOOPS
	for(;testResults && safety > 0; safety--) {
		let result = await runStatement(0, [body], runContext)
		if(runContext.broken) {
			runContext.broken = false
			break
		}
		if(!isStillRunning(runContext)) {
			return
		}
		await runStatement(0, [update], runContext)
		if(!isStillRunning(runContext)) {
			return
		}
		testResults = await runStatement(0, [test], runContext)
		if(!isStillRunning(runContext)) {
			return
		}
	}
	if(!isStillRunning(runContext)) {
		return
	}
// SO I'M NOT A HYPOCRITE LETS PUT SOME REASONABLE BOUNDS!
	if(safety == 0) {
		throw new Error('Long running for loop!')
	}
	return result
}

async function runWhile(AST, runContext) {
  let result
  let safety = LONG_LOOPS
  do {
    result = await runStatement(0, [AST.body], runContext)
		if(runContext.broken) {
			runContext.broken = false
			break
		}
    if(!isStillRunning(runContext)) {
      return
    }
    testResults = await runStatement(0, [AST.test], runContext)
    if(!isStillRunning(runContext)) {
      return
    }
  } while (testResults && --safety > 0)
	if(!isStillRunning(runContext)) {
		return
	}
	return result
}
