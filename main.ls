#!./node_modules/.bin/lsc --const

'use strict'

# requiring it first, so I can enable cancellation
# before doing anything else

# global, so I don't accidentaly use native promise
# expecting it to have all bluebird's goodies
global.Promise = require 'bluebird'

Promise.config do
	cancellation: true

# this is the 2nd thing I require
# because it initiates getMe request to the api
# and initiating it before other requires
# *may* speed up startup.
# Haven't observed any speed up, though.
require! './objects': {
	bot
	responder
	promise-me
}

require! './alias'
require! './callback-handler'
require! './constants': {
	command
	execute
	language-regex
}
require! './core-command-handler'
require! './document-handler'
require! './inline-handler'

require! 'lodash'


global.verbose = lodash process.argv
	.slice 2
	.some -> it == '-v' or it == '--verbose'

url = process.env.NOW_URL


function run-async generator
	Promise.coroutine(generator)!

*<- run-async


me = yield promise-me
global.botname = me.username

# those need botname before being required.
# Maybe it's slower than previous implementation,
# but I believe it's cleaner?
# I may be able to design it better next time.
require! './execurl'
require! './gimme-code'
require! './help'




bot.on-text command('lang(uage)?s'), help.send-langs
bot.on-text command('about'), help.about
bot.on-text command('stat(istic)?s'), help.send-stats
bot.on-text command(['help', 'start']), help.help
bot.on-text command('alias', '([\\s\\S]*?)', args-are-optional: true), alias.handler
bot.on-text execurl.regex, execurl.handler


global.regex = //^/
	(#language-regex)
	(?:@(#botname))?
	\s+
	([\s\S]+?) # code
	(?:
		\s+
		/stdin
		\s+
		([\s\S]+) # stdin
	)?
$//i



bot.on-text command('cancel'), gimme-code.cancel
bot.on-text command("(#language-regex)"), gimme-code.missing-source


bot.on-text command('start', "([\\w-]+)"), (msg, [,, command]) ->
	bot.process-update(message: msg with {text: '/' + command.replace(/\-/g, ' ')})

bot.on-text regex, core-command-handler

bot.on-text ////, gimme-code.anything


# small hack, wraps all of the callbacks above
# to add additional check
# not elegant, not future-proof
# but it's the only DRY approach I can think of

# for my next bot, I'll choose a framework
# which has neat way of implementing this
# I'm interested in like 4 of them
# but I can't decide which one to use
bot._text-regexp-callbacks .= map ({regexp, callback}) -> {
	regexp
	callback: (msg) ->
		callback ... if not msg.forward_from or msg.chat.type == 'private'
}


bot.on 'inline_query', inline-handler
bot.on 'callback_query', callback-handler

bot.on 'edited_message_text', (msg) ->
	msg._edit = true
	bot.process-update message: msg


bot.on 'document', document-handler



if url?
	yield bot.open-web-hook!
	yield bot.set-web-hook "#url/#token"
else
	yield bot.start-polling!

console.info 'Bot started.'
