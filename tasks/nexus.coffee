"use strict"
Q = require 'q'

module.exports = (grunt) ->
	NexusArtifact = require('../lib/nexus-artifact')(grunt)
	util = require('../lib/util')(grunt)

	# shortcut to underscore
	_ = grunt.util._

	grunt.registerMultiTask 'nexus', 'Download an artifact from nexus', ->
		done = @async()

		# defaults
		options = this.options
			url: ''
			base_path: 'nexus/content/repositories'
			repository: ''
			versionPattern: '%a-%v.%e'
			username: ''
			password: ''

		processes = []

		if !@args.length or _.contains @args, 'fetch'
			_.each options.fetch, (cfg) ->
				# get the base nexus path
				_.extend cfg, NexusArtifact.fromString(cfg.id) if cfg.id

				_.extend cfg, options

				artifact = new NexusArtifact cfg

				processes.push util.download(artifact, cfg.path)

		if @args.length and _.contains @args, 'publish'
			_.each options.publish, (cfg) =>
				artifactCfg = {}
				_.extend artifactCfg, NexusArtifact.fromString(cfg.id), cfg if cfg.id

				_.extend artifactCfg, options

				artifact = new NexusArtifact artifactCfg
				processes.push util.publish(artifact, @files, { path: cfg.path, credentials: { username: options.username, password: options.password }} )

		Q.all(processes).then(() ->
			done()
		).fail (err) ->
			grunt.fail.warn err
