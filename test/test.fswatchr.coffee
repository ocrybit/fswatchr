fs = require('fs')
path = require('path')

async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()

FSWatchr = require('../lib/fswatchr')

describe('FSWatchr', ->
  TMP = "#{__dirname}/tmp"
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  FILTER = ->
  HOTCOFFEE = "#{TMP}/hot.coffee"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  AMERICANCOFFEE = "#{FOO2}/american.coffee"
  fswatchr = new FSWatchr()
  stats = {}

  beforeEach((done) ->
    mkdirp(FOO, (err) ->
      async.forEach(
        [HOTCOFFEE, ICEDCOFFEE],
        (v, callback) ->
          fs.writeFile(v, '', (err) ->
            async.forEach(
              [FOO, HOTCOFFEE,ICEDCOFFEE,BLACKCOFFEE, AMERICANCOFFEE],
              (v, callback2) ->
                fs.stat(v, (err,stat) ->
                  stats[v] = stat
                  callback2()
                )
              ->
                callback()
            )
          )
        ->
          fswatchr = new FSWatchr(TMP)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) ->
      fswatchr.removeAllListeners()
      done()
    )
  )

  describe('constructor', ->
    it('init test', ->
      FSWatchr.should.be.a('function')
    )
    it('should instanciate', ->
      fswatchr.should.be.a('object')
    )
  )

  describe('_checkMtime', ->
    it('return true is stats.mtime is the same', (done) ->
      fswatchr.stats[TMP] = {}
      fswatchr.stats[TMP][HOTCOFFEE] = stats[HOTCOFFEE]
      fswatchr._checkMtime(HOTCOFFEE, stats[HOTCOFFEE]).should.be.ok
      fs.utimes(HOTCOFFEE, Date.now(), Date.now(), ->
        fs.stat(HOTCOFFEE, (err,stats) ->
          fswatchr._checkMtime(HOTCOFFEE, stats[HOTCOFFEE]).should.not.be.ok
          done()
        )
      )
    )
  )

  describe('_getAction', ->
    it('specify the action taken on a file', (done) ->
      fswatchr._getAction(
        'rename',
        HOTCOFFEE,
        stats[HOTCOFFEE]
      ).should.equal('created')
      fswatchr.stats[TMP] = {}
      fswatchr.stats[TMP][HOTCOFFEE] = stats[HOTCOFFEE]
      fswatchr._getAction(
        'change',
        HOTCOFFEE,
        stats[HOTCOFFEE]
      ).should.equal('unchanged')
      fs.utimes(HOTCOFFEE, Date.now(), Date.now(), ->
        fs.stat(HOTCOFFEE, (err,stats) ->
          fswatchr._getAction(
            'change',
            HOTCOFFEE,
            stats[HOTCOFFEE]
          ).should.equal('changed')
          fswatchr._getAction(
            'rename',
            HOTCOFFEE,
            null
          ).should.equal('removed')
          done()
        )
      )
    )
  )

  describe('_close', ->
    it('close the watcher for a directory', (done) ->
      fswatchr.on('watchset', ->
          should.exist(fswatchr.watchers[FOO])
          fswatchr._close(FOO)
          should.not.exist(fswatchr.watchers[FOO])
          done()
      )
      fswatchr.watch()
    )
    it("shouldn't emit after close", (done) ->
      fswatchr.once('dir removed', (dir) ->
        true.should.not.ok
        done()
      )
      fswatchr.on('watchset', ->
        fswatchr._close(TMP)
        fswatchr.kill()
        rimraf(FOO, ->
          true.should.ok
          done()
        )
      )
      fswatchr.watch()
    )
  )

  describe('watch', ->
    it('emit "Directory created" event', (done) ->
      fswatchr.once('Directory created', (dir) ->
        dir.should.equal(FOO2)
        done()
      )
      fswatchr.on('watchset', ->
        fs.mkdir(FOO2)
      )
      fswatchr.watch()
    )
    it('emit "File created" event', (done) ->
      fswatchr.once('File created', (file) ->
        file.should.be.equal(BLACKCOFFEE)
        done()
      )
      fswatchr.on('watchset', ->
        fs.writeFile(BLACKCOFFEE, '')
      )
      fswatchr.watch()
    )
    it("shouldn't emit if @filter is set", (done) ->
      fswatchr.setFilter((file, stats) ->
        return file is BLACKCOFFEE
      )
      fswatchr.once('File created', (file) ->
        if file is BLACKCOFFEE
          true.should.not.ok
          done()
      )
      fswatchr.on('watchset', ->
        fs.writeFile(BLACKCOFFEE, '')
      )
      fswatchr.watch()
      done()
    )
    it('emit "Directory removed" event', (done) ->
      fswatchr.once('Directory removed', (dir) ->
        dir.should.equal(FOO)
        done()
      )
      fswatchr.on('watchset', ->
        rimraf(FOO, ->)
      )
      fswatchr.watch()
    )
    it('should emit "File removed" event',(done)->
      fswatchr.once('File removed', (file) ->
        file.should.equal(HOTCOFFEE)
        done()
      )
      fswatchr.on('watchset', ->
        fs.unlink(HOTCOFFEE, ->)
      )
      fswatchr.watch()
    )
    it('should emit "File changed" event', (done) ->
      fswatchr.once('File changed', (file) ->
        file.should.equal(HOTCOFFEE)
        done()
      )
      fswatchr.on('watchset', ->
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
      fswatchr.watch()
    )
    it('emit "watchstart" event', (done) ->
      fswatchr.once('watchstart', (dir) ->
        dir.should.equal(TMP)
        done()
      )
      fswatchr.watch()
    )
    it('emit "watchset" event', (done) ->
      fswatchr.once('watchset', (dirname, filestats) ->
        dirname.should.equal(TMP)
        filestats.should.be.a('object')
        done()
      )
      fswatchr.watch()
    )
    it('watch inside a newly created dir', (done) ->
      fswatchr.once('watchset', (dir) ->
        dir.should.equal(TMP)
        fswatchr.on('watchstart', (dir, stat) ->
          if dir is FOO2
            fswatchr.on('File created', (file) ->
              file.should.equal(AMERICANCOFFEE)
              done()
            )
            fs.writeFile(AMERICANCOFFEE,'')
        )
        fs.mkdir(FOO2)
      )
      fswatchr.watch()
    )
    it('ignore files when @filter function is set', (done) ->
      fswatchr.setFilter((file, stats) ->
        return file is FOO
      )
      fswatchr.on('watchstart', (dir, stat) ->
        if dir is FOO
          true.should.not.ok
          done()
      )
      fswatchr.watch()
      done()
    )
  )
  describe('kill', ->
    it("shouldn't emit after kill", (done) ->
      fswatchr.once('dir removed', (dir) ->
        true.should.not.ok
        done()
      )
      fswatchr.on('watchset', ->
        fswatchr.kill()
        rimraf(FOO, ->
          true.should.ok
          done()
        )
      )
      fswatchr.watch()
    )
  )
  describe('setFilter',() ->
    it('set a filter function', () ->
      should.not.exist(fswatchr.filter)
      fswatchr.setFilter(FILTER)
      fswatchr.filter.should.be.a.instanceOf(Function)
    )
  )

)