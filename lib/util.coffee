request = require 'request'
targz = require 'tar.gz'
zip = require 'adm-zip'
fs = require 'fs'
Q = require 'q'
crypto = require 'crypto'
urlUtil = require 'url'

module.exports = (grunt) ->

  compress = require('grunt-contrib-compress/tasks/lib/compress')(grunt)

  extract = (ext, temp_path, path, deferred) ->
    grunt.verbose.writeln "Extract #{ext} #{temp_path}, #{path}"
    if ext is 'tgz'
      @archive = new targz()
      @archive.extract(temp_path, path, (err) ->
        grunt.verbose.writeln "Extraction done #{err}"
        if(err)
          deferred.reject { message: 'Error extracting archive' + err }
        deferred.resolve()
      )

    if ext is 'zip'
      archive = new zip(temp_path)
      archive.extractAllTo(path, true);
      deferred.resolve()

  downloadFile = (options, artifact, path, temp_path) ->
    deferred = Q.defer()

    grunt.log.writeln "Downloading #{artifact.buildUrl()}"
    file = request.get(artifact.buildUrl(), options, (error, response) ->
      if error
        deferred.reject {message: 'Error making http request: ' + error}
      else if response.statusCode isnt 200
        deferred.reject {message: 'Request received invalid status code: ' + response.statusCode}

      grunt.verbose.writeln "Download complete"
      file.end
    ).pipe(fs.createWriteStream(temp_path))

    file.on 'close', ()->
      grunt.verbose.writeln "Start Extracting..."
      extract artifact.ext, temp_path, path, deferred

    grunt.verbose.writeln "Downloading ..."
    deferred.promise

  upload = (data, url, credentials, isFile = true) ->
    deferred = Q.defer()

    options = grunt.util._.extend {method: 'PUT', url: url}
    if credentials.username
      options = grunt.util._.extend options, {auth: credentials}

    grunt.verbose.writeflags options

    if isFile
      file = fs.createReadStream(data)
      file.pipe(request.put(options, (error, response) ->
        if error
          deferred.reject {message: 'Error making http request: ' + error}
        else if response.statusCode is 201
          deferred.resolve()
        else
          deferred.reject {message: 'Request received invalid status code: ' + response.statusCode}
      ))
    else
      deferred.resolve()

    deferred.promise

  publishFile = (options, filename, urlPath) ->
    deferred = Q.defer()

    generateHashes(options.path + filename).then (hashes) ->

      url = urlPath + filename
      promises = [
        upload options.path + filename, url, options.credentials
      ]

      Q.all(promises).then () ->
        deferred.resolve()
      .fail (error) ->
          deferred.reject error
    .fail (error) ->
        deferred.reject error

    deferred.promise

  generateHashes = (file) ->
    deferred = Q.defer()

    md5 = crypto.createHash 'md5'
    sha1 = crypto.createHash 'sha1'

    stream = fs.ReadStream file

    stream.on 'data', (data) ->
      sha1.update data
      md5.update data

    stream.on 'end', (data) ->
      hashes =
        md5: md5.digest 'hex'
        sha1: sha1.digest 'hex'
      deferred.resolve hashes

    stream.on 'error', (error) ->
      deferred.reject error

    deferred.promise

  return {

  ###*
  * Download an artifactory artifact and extract it to a path
  * @param {ArtifactoryArtifact} artifact The artifactory artifact to download
  * @param {String} path The path the artifact should be extracted to
  *
  * @return {Promise} returns a Q promise to be resolved when the file is done downloading
  ###
  download: (artifact, path, options) ->
    deferred = Q.defer()

    if grunt.file.exists("#{path}/.version") and (grunt.file.read("#{path}/.version").trim() is artifact.version)
      grunt.log.writeln "Up-to-date: #{artifact}"
      return

    grunt.file.mkdir path

    temp_path = "#{path}/#{artifact.buildArtifactUri()}"

    downloadFile(options, artifact, path, temp_path).then( ->
      grunt.log.writeln "Download and unpack done."
      deferred.resolve()
    ).fail (error) ->
      grunt.log.writeln "Download and unpack Error: #{error}"
      deferred.reject error

    deferred.promise

  ###*
  * Publish a path to artifactory
  * @param {ArtifactoryArtifact} artifact The artifactory artifact to publish to artifactory
  * @param {String} path The path to publish to artifactory
  *
  * @return {Promise} returns a Q promise to be resolved when the artifact is done being published
  ###
  publish: (artifact, files, options) ->
    deferred = Q.defer()
    filename = artifact.buildArtifactUri()
    archive = "#{options.path}#{filename}"

    if(grunt.util._.endsWith(archive, '.war'))
      mode = 'zip'
    else
      mode = compress.autoDetectMode(archive)

    compress.options =
      archive: archive
      mode: mode

    compress.tar files, () ->
      publishFile(options, filename, artifact.buildUrlPath()).then( ->
        deferred.resolve()
      ).fail (error) ->
        deferred.reject error

    deferred.promise
  }
