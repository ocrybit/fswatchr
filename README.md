FSWatchr
========

A recursive fs.watch for Node.js that recursively walks throught a directory tree, deploy `fs.FSWatcher` on each directory, and throws back better event reports than the original `fs.watch` method.  

Note FSWatchr uses `fs.watch` method and **not** `fs.watchFile`.  

`fs.watchFile` is not recommended beause it is slower and less reliable according to [the node.js api document](http://nodejs.org/api/fs.html#fs_fs_watchfile_filename_options_listener).

But `fs.watch` is not 100% platform compatible and `FSWatchr` doesn't have a fallback mechanism at the moment. See the availability on [the node document](http://nodejs.org/api/fs.html#fs_caveats).

Installation
------------

    sudo npm install fswatchr
	
Usage
-----

    # a temp directory for this example  
	TMP = "#{__dirname}/tmp"
	
	FSWatchr = require('fswatchr)
	
	#instantiate with the root path to watch
	fswatchr = new FSWatchr(TMP)
	
	# set up some listeners
	fswatchr.on('File found', (filepath, stat) ->
	  console.log("File: #{filepath} is found!")
	)
	
	fswatchr.on('File changed, (filepath, stat) ->
	  console.log("File: #{filepath} is changed!")
	)
	
	# start the recursive watch process
	fswatchr.watch()
	
	#stop the watch process
	fswatchr.kill()

File Types
----------

7 file types are supported and FSWatchr emits corresponding events in combination with the event types described in the next section.  

Note those event names are capitalized.  

`File` `Directory` `BlockDevice` `FIFO` `Socket` `CharacterDevice` `SymbolicLink`

Other file types will still be found and marked `Unknown`.  

Listener functions will have `filepath` and `stats` from `fs.lstat()`

   	fswatchr.on('File found', (filepath, stat) ->
	  console.log("FilePath: #{filepath}")
	  console.log("Stats: #{stats}")	  
	)

File Type Specific Event types
------------------------------

Each of 7 file types will be broadcasted on the 5 events below...

`found` `created` `changed` `unchanged` `removed`

So for instance, `File` has these 5 events.

`File found` `File created` `File changed` `File unchanged` `File removed`

FSWathchr reads the directory contents before it starts watching each directory. `found` events are emitted during that initial `readdir` operations, thus happens only once for each file.

`unchanged` will be emitted when a file is accessed, but not modified.

So there are possibly 80 different events (7 file types + `Unknown` multiplied by 5 event types), plus we have 7 more non-file-type-specific-events

Non File Type Specific Event types
----------------------------------

Once again, these 5 event types are broadcasted without the file type prefixes.

`found` `created` `changed` `unchanged` `removed`

And the file types of each event are accessible at the third passed value to the listener function.

   	fswatchr.on('created`, (filepath, stat, type) ->
	  console.log("FilePath: #{filepath}")
	  console.log("Stats: #{stats}")
	  console.log("FileType: #{type}")	  
	)

You can listen to eather file-type-specific-events or non-file-type-specific-events to get the same results.

There are 2 more events.

`watchstart` will be emitted when FSWatchr successfully set a `fs.FSWatcher` to each of the directories. So if there are 3 directories inside the root directory (assume there are no third level sub directries), `watchstart` will be emitted 4 times including the root directory.

   	fswatchr.on('watchstart`, (direpath, stats) ->
	  console.log("started watching #{dirpath}")
	  
	  for filepath, stat of stats
	    console.log("Stats for #{filepath}")
        console.log(stat)
      )

`watchset` will be emitted when FSWachr finish deploying all the `fs.FSWatcher`es to the entire directory tree starting from the given root. So it will initially be emitted only once.  

Note if a new directory is created, FSWatchr initiates the `readdir` and `fs.FSWatcher` deploying process for that new directory. So another `watchset` will be emitted for the new directory.

   	fswatchr.on('watchset`, (direpath, stats) ->
	  console.log("finish deploying for #{dirpath}")
	  
	  # watchset returns the stats of the entire files under the watch of the FSWatchr instance
	  for filepath, stat of stats
	    console.log("Stats for #{filepath}")
        console.log(stat)
      )

Filter Function
---------------

A filter function can be set to ignore files and directories. If a directory is ignored, FSWatchr doesn't go into that directory, so the sub contents under the directorey are all ignored, thus events are unreported.

	fswatchr.setFilter((filepath, stat) ->
	  return filepath is "#{TMP}/ignore.coffee"
	)
    
Running Tests
-------------

Run tests with [mocha](http://mochajs.org/)

    make
	

License
-------
**FSWatchr** is released under the **MIT License**. - see [LICENSE](https://raw.github.com/tomoio/fswatchr/master/LICENSE) file
.
