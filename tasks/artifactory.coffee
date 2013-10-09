"use strict"
Q = require 'q'

module.exports = (grunt) ->
	ArtifactoryArtifact = require('../lib/artifactory-artifact')(grunt)
	util = require('../lib/util')(grunt)

	# shortcut to underscore
	_ = grunt.util._

	grunt.registerMultiTask 'artifactory', 'Download an artifact from artifactory', ->
		done = @async()

		# defaults
		options = this.options
			url: ''
			base_path: 'artifactory'
			repository: ''
			versionPattern: '%a-%v.%e'
			username: ''
			password: ''

		processes = []

		if !@args.length or _.contains @args, 'fetch'
			_.each options.fetch, (cfg) ->
				# get the base artifactory path
				_.extend cfg, ArtifactoryArtifact.fromString(cfg.id) if cfg.id

				_.extend cfg, options

				artifact = new ArtifactoryArtifact cfg
				reqOpts = {}
				if(options.username)
				  reqOpts = {'auth':{'user':options.username, 'pass':options.password}}

				processes.push util.download(artifact, cfg.path, reqOpts)

		if @args.length and _.contains @args, 'publish'
			_.each options.publish, (cfg) =>
				artifactCfg = {}
				_.extend artifactCfg, ArtifactoryArtifact.fromString(cfg.id), cfg if cfg.id

				_.extend artifactCfg, options

				artifact = new ArtifactoryArtifact artifactCfg
				processes.push util.publish(artifact, @files, { path: cfg.path, credentials: { username: options.username, password: options.password }} )

		Q.all(processes).then(() ->
			done()
		).fail (err) ->
			grunt.fail.warn err
