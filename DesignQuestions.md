Deferred design decisions
* How do we disentangle sync, usercache and the data in the user cache?
  * In particular, consider the check for when to send the data and clear and the cache. Currently, on android, the usercache determines the last timestamp from which to send data, and does the serialization/deserialization. On iOS, the determination is split between the usercache and the DataUtils code. But really, it should be in the location code. If we store data from other sources (e.g. client stats) into the usercache, then we don't necessarily need to wait until the trip end to push the data. But then, we need to track the source of all the data in the cache, which we don't currently do. There's actually a trifecta here:
     * sync, which should take care of the communication with the server
     * usercache, which is a simple replicated JSON store
     * sources, which get and put data from the store, and are responsible for cleaning out the cache and so on 
* It is also not clear whether the sync should be separate from the usercache.  We can consider the cache as a magically replicating database, and that's what the other implementations (Firebase, Azure, PouchDB) seem to do. Then we only have two things - the usercache and the sources, and having a nice interface to the usercache means that we can easily swap it out for other implementations. Also, in the case of iOS, "sync" is really driven by remote push.

Punting on this for now and retaining the current, somewhat convoluted trifecta of sync, usercache and data collection. Need to revisit in the future.
So currently, we have:
- usercache: defines push and pull methods
- stats: defines push and pull methods
- sync: calls push and pull methods on both hardcoded entities

I was going to use the remote notifications plugin here, but it looks like it
only calls back to javascript, not to native code. Here, we want to call back
to native code since we want to sync in the background. So let's replicate the
code from the remote notifications plugin here.

iOS only
--------
Wait a minute. We need remote notifications for both the location tracking
state machine, and for the sync. Do we register for notifications once or twice?

- If once, then we add a dependency from this to the location tracking code,
  which seems bad
- If twice, I am not sure if a single app is allowed to register for notifications twice

For now, I will fork the push notifications plugin and change it to generate a
broadcast that native code can listen to as well. I will listen to these
notifications from the location code and have it invoke the sync code as it
does now. That particular callback was fairly fragile, and I don't want to mess
with it while changing everything else as well.

This does need to be disentangled later.
