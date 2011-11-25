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

		@awakenable.first.read_nonblock 1337 rescue nil

		unless @awakened
			IO.select([@awakenable.first], nil, nil, time)
		else
			@awakened = false
		end
	end

	def wake_up
		@awakenable ||= IO.pipe

		@awakenable.last.write 'x'
		@awakened = true
	end
end

class ThreadPool
	class Worker
		include Awakenable

		def initialize (watcher = nil)
			@watcher = watcher
			@mutex   = Mutex.new

			@thread = Thread.new {
				loop do
					if @block
						@block.call(*@args) rescue nil

						@block = nil
						@args  = nil

						@watcher.wake_up if @watcher
					else
						sleep

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

	def_delegators :@watcher, :kill, :die?, :dead?

	def initialize (size = 2)
		@size    = 0
		@queue   = Queue.new
		@pool    = []
		@watcher = Worker.new
		
		@watcher.process {
			loop do
				@watcher.sleep if @queue.empty?
				next           if @queue.empty?

				begin
					worker = @pool.find(&:available?) or @watcher.sleep
				end until worker

				break if @watcher.die?

				args, block = @queue.pop

				worker.process(*args, &block)
			end

			@pool.each(&:kill)
		}

		resize(size)
	end

	def join
		@watcher.join
	end; alias wait join

	def resize (size)
		return if @size == size

		if @size < size
			1.upto(size - @size) {
				@pool << Worker.new(@watcher)
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
