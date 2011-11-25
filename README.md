ThreadPool - an implementation that doesn't waste CPU resources
===============================================================
All the implementations I looked at were either buggy or wasted CPU resources
for no apparent reason, for example used a sleep of 0.01 seconds to then check for
readiness and stuff like this.

This implementation uses `IO.select` instead, there is no timed sleep, it just only stays
there waiting for input, which will then come from a `#wake_up` call that writes on a pipe.

`IO.select` should be present everywhere so this should be cross-platform and doesn't waste
CPU resources. Keep in mind that each worker uses 2 file descriptors (reading and writing pipe).

Example
-------

```ruby
require 'threadpool'

pool = ThreadPool.new
pool.resize(4)

0.upto(10) { pool.process { sleep 2; puts 'lol' } }
```

You should get 4 lols every 2 seconds.
