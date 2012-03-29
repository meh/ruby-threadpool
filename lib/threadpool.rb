#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'thread'

class ThreadPool
	attr_reader :min, :max, :spawned

	def initialize (min, max = nil, &block)
		@min   = min
		@max   = max || min
		@block = block

		@cond  = ConditionVariable.new
		@mutex = Mutex.new

		@todo    = []
		@workers = []

		@spawned       = 0
		@waiting       = 0
		@shutdown      = false
		@trim_requests = 0

		@mutex.synchronize {
			min.times {
				spawn_thread
			}
		}
	end

	def resize (min, max = nil)
		@min = min
		@max = max || min

		trim!
	end

	def backlog
		@mutex.synchronize {
			@todo.length
		}
	end

	def process (*args, &block)
		@mutex.synchronize {
			raise 'unable to add work while shutting down' if @shutdown

			@todo << [args, block]

			if @waiting == 0 && @spawned < @max
				spawn_thread
			end

			@cond.signal
		}
	end

	alias << process

	def trim (force = false)
		@mutex.synchronize {
			if (force || @waiting > 0) && @spawned - @trim_requests > @min
				@trim_requests -= 1
				@cond.signal
			end
		}
	end

	def trim!
		trim true
	end

	def shutdown
		@mutex.synchronize {
			@shutdown = true
			@cond.broadcast
		}

		@workers.first.join until @workers.empty?
	end

private
	def spawn_thread
		@spawned += 1

		thread = Thread.new {
			loop do
				work     = nil
				continue = true

				@mutex.synchronize {
					while @todo.empty?
						if @trim_requests > 0
							@trim_requests -= 1
							continue = false

							break
						end

						if @shutdown
							continue = false

							break
						end

						@waiting += 1
						@cond.wait @mutex
						@waiting -= 1

						if @shutdown
							continue = false

							break
						end
					end

					work = @todo.shift if continue
				}

				break unless continue

				(work.last || @block).call(*work.first)
			end

			@mutex.synchronize {
				@spawned -= 1
				@workers.delete thread
			}
		}

		@workers << thread

		thread
	end
end
