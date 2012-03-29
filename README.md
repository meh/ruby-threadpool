ThreadPool - an implementation that doesn't waste CPU resources
===============================================================
All the implementations I looked at were either buggy or wasted CPU resources
for no apparent reason, for example used a sleep of 0.01 seconds to then check for
readiness and stuff like this.

This implementation uses standard locking functions to work properly across multiple Ruby
implementations.

Example
-------

```ruby
require 'threadpool'

pool = ThreadPool.new(4)

0.upto(10) { pool.process { sleep 2; puts 'lol' } }

gets # otherwise the program ends without the pool doing anything
```

You should get 4 lols every 2 seconds.
