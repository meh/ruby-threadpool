#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'forwardable'
require 'thread'

module Awakenable
	def sleep (time = nil)
		@awakenable ||= IO.pipe

		begin
			@awakenable.first.read_nonblock 2048
		rescue Errno::EAGAIN; end

		IO.select([@awakenable.first], nil, nil, time)
	end

	def wake_up
		@awakenable ||= IO.pipe
		@awakenable.last.write 'x'
	end
end

class ThreadPool
	class Worker
		include Awakenable

		def initialize (pool)
			@pool  = pool
			@mutex = Mutex.new

			@thread = Thread.new {
				loop do
					if @block
						begin
							@block.call(*@args)
						rescue Exception => e
							@pool.raise(e)
						end

						@block = nil
						@args  = nil

						@pool.wake_up
					else
						sleep unless die?
						break if die?
					end
				end
			}
		end

		def available?
			@mutex.synchronize {
				!@block
			}
		end

		def process (*args, &block)
			return unless available?

			@mutex.synchronize {
				@block = block
				@args  = args

				wake_up
			}
		end

		def join
			@thread.join
		end

		def kill
			return if die?

			@die = true
			wake_up
		end

		def die?
			@die
		end

		def dead?
			@thread.stop?
		end
	end

	extend Forwardable

	attr_reader    :watcher, :size
	def_delegators :@watcher, :sleep, :wake_up, :kill, :die?, :dead?, :join
	def_delegators :@current, :raise

	def initialize (size = 2)
		@size    = 0
		@queue   = Queue.new
		@pool    = []
		@watcher = Worker.new(self)
		@current = Thread.current
		
		@watcher.process {
			loop do
				sleep if @queue.empty?
				next  if @queue.empty?

				begin
					worker = @pool.find(&:available?) or sleep
				end until worker

				break if die?

				args, block = @queue.pop

				worker.process(*args, &block)
			end

			@pool.each(&:kill)
		}

		resize(size)
	end

	def resize (size)
		return if @size == size

		if @size < size
			1.upto(size - @size) {
				@pool << Worker.new(self)
			}
		else
			1.upto(@size - size) {
				@pool.pop.kill
			}
		end

		@size = size
	end

	def process (*args, &block)
		@queue.push([args, block])
		@watcher.wake_up
	end; alias do process
end
