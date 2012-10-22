# * Watch a directory and emit events when files are created, changed, and removed

# ---

# ### Require Dependencies

# #### Standard Node Modules
# `events` : [Events](http://nodejs.org/api/events.html)  
# `fs` : [File System](http://nodejs.org/api/fs.html)  
# `path` : [Path](http://nodejs.org/api/path.html)  
EventEmitter = require('events').EventEmitter
fs = require('fs')
path = require('path')

# #### Third Party Modules
# `async` by [Caolan McMahon@caolan](https://github.com/caolan/async)  
# `dirwalker` by [Tomo I/O@tomoio](https://github.com/tomoio/dirwalker)  
async = require('async')
DirWalker = require('dirwalker')
# ---

# ## FSWatcher Class
module.exports = class FSWatchr extends EventEmitter

  # ### Class Properties
  # `@dir (String)` : a directory path to watch  
  # `@dirs (Object)` : stats of files and directories under the watch  
  # `@watcher (Object)` : [`fs.FSWatcher`](http://nodejs.org/api/fs.html#fs_class_fs_fswatcher) object
 
  # ### Events
  # `file created` : a file is created  
  # `file changed` : a file is changed  
  # `file removed` : a file is removed  
  # `dir created` : a directory is created  
  # `dir changed` : a directory is changed  
  # `dir removed` : a directory is removed  
  # `watchstart` : `fs.watch` started for a directory  
  # `watchset` : all the `fs.watch`es are set  
    
  # #### constructor
  # `@dir` : see *Class Properties* section  
  constructor: (@dir = process.cwd()) ->
    @stats = {}
    @watchers = {}
  # ---

  # ### Private Methods

  # #### Check if the mtime of the previous stats and the new stats are the same
  # `filename (String)` : filename  
  # `stats (object)` : the new stats of the file 
  _checkMtime: (filename, newstats) ->
    # get the previously stored stats for the `filename`
    oldstats = @stats[path.dirname(filename)]?[filename]
    if oldstats?.mtime?.getTime() is newstats?.mtime?.getTime()
      return true
    else
      return false

  # #### Specify the action taken on the file
  # `event (String)` : an event name  
  # `filename (String)` : a file name  
  # `stats (Object)` : a stats object
  _getAction: (event, filename, stats) ->
    switch event
      when 'rename'
        # If the stats object is not stored in `@dirs`, the file is newly `created`
        return if (@stats[path.dirname(filename)]?[filename]? and not stats?) then 'removed' else 'created'
      when 'change'
        # If the `mtime` hasn"t changed, the file content is `unchanged`
        return if @_checkMtime(filename, stats) then 'unchanged' else 'changed'
  
  # #### Close the watcher for a directory
  _close: (dirname) ->
    @watchers[dirname]?.close()
    delete @watchers[dirname]
    delete @stats[dirname]
    delete @stats[path.dirname(dirname)]?[dirname]

  # ---

  # ### Public API
 
  # #### Watch directory and emit events when changes are found
  # `dirname (Function)` : a directory path to watch
  watch: (dirname = @dir) ->
    dirwalker = new DirWalker(dirname)
    if @filter
      dirwalker.setFilter(@filter)
    for v in dirwalker.FILE_TYPES
      ((type) =>
        dirwalker.on(type, (file, stat) =>
          @emit("#{type} found", file, stat)
        )
      )(v)
    dirwalker.on('read', (dirpath, dirstats) =>
      @stats[dirpath] = dirstats
      @watchers[dirpath] = fs.watch(dirpath, (event, filename) =>
        p = path.join(dirpath, filename)
        fs.lstat(p, (err, stat) =>
          # `fs.watch` watches not only the sub contents in the dir but also the containing dir itself.
          # If `fs.lstat` returns err and no pre-stored stat object is found,
          # that probably means this watch event is about the containing dir,
          # and we can ignore that.  
          # If there is a file with the same name as the containing dir... can't really tell which.
          # `fs.watch` only returns the basename of a file, without the dirname.
          if (stat? or @stats[dirpath]?[p]?) and not @filter?(p, stat)
            action = @_getAction(event, p, stat)
            type = dirwalker.getFileType(stat ? @stats[dirpath]?[p])
            if action is 'removed' and @stats[dirpath]?[p]?
              # Remove the stored stats
              delete @stats[dirpath][p]
            else if stats?
              # Replace the stored stats with new stats
              @stats[path.dirname(filename)][filename] = stat
            unless not type or action is 'unchanged'
              # emit `created`, `changed` and `removed` events for files and directories
              @emit("#{type} #{action}", p, stat)
            if type is 'Directory'
              if action is 'created'
                @watch(p)
              else if action is 'removed'
                @_close(p)
        )
      )
      @emit("watchstart", dirpath, @stats[dirpath])
    )
    dirwalker.on('end', =>
      flatstats = {}
      #flatten @stats
      for k, v of @stats
        for k2, v2 of v
          flatstats[k2] = v2
      @emit("watchset", dirname, flatstats)
    )
    dirwalker.walk()

  # #### Close all the fs.FSWatcher and remove stored stats
  kill: ->
    for k, v of @watchers
      v.close()
    @stats = {}

  # #### Set a filter function
  # `fn (Function)` : a filter `Function`
  setFilter: (fn) ->
    if typeof(fn) is 'function'
      @filter = fn
