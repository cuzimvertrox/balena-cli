_ = require('lodash')
request = require('request')
progress = require('request-progress')
urlResolve = require('url').resolve
async = require('async')
connection = require('../../connection/connection')
config = require('../config')
token = require('../token/token')

exports.request = (options = {}, callback, onProgress) ->

	onProgress ?= _.noop

	if not options.url?
		throw new Error('Missing URL')

	async.waterfall [

		(callback) ->
			connection.isOnline(callback)

		(isOnline, callback) ->
			if not isOnline
				return callback(new Error('You need internet connection to perform this task'))

			token.getToken(callback)

		(savedToken, callback) ->
			options.url = urlResolve(config.remoteUrl, options.url)

			if options.method?
				options.method = options.method.toUpperCase()

			_.defaults options,
				method: 'GET'
				gzip: true

			if savedToken?
				options.headers ?= {}
				_.extend options.headers,
					'Authorization': "Bearer #{savedToken}"

			progress(request(options, callback))
				.on('progress', onProgress)
				.on('error', callback)
				.on('end', onProgress)

		(response, body, callback) ->
			try
				response.body = JSON.parse(response.body)

			if response?.statusCode >= 400
				error = new Error(response.body)

			return callback(error, response, response.body)

	], callback

createFacadeFunction = (method) ->
	lowerCaseMethod = method.toLowerCase()
	exports[lowerCaseMethod] = (url, body, callback, onProgress) ->
		options = {
			method
			url
		}

		if _.isFunction(body)
			onProgress = callback
			callback = body
		else
			options.json = body

		return exports.request(options, callback, onProgress)

for method in [
	'GET'
	'HEAD'
	'POST'
	'PATCH'
	'PUT'
	'DELETE'
]
	createFacadeFunction(method)
