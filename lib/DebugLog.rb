require "logger"

# 0 DEBUG
# 1 INFO
# 2 WARN
# 3 ERROR
# 4 FATAL
# 5 UNKNOWN

module DebugLog

    @@logger = Logger.new(STDERR)
    
    def DebugLog.append_features(includingClass)
        super
        def includingClass.log_level(log_level)
            if @logger
                @logger.level = log_level
            else
                @@logger.level = log_level
            end
        end
        
        def includingClass.global_logger=(new_logger)
            @@logger = new_logger
        end
        
        def includingClass.global_logger
            @@logger
        end
        
        def includingClass.logger=(new_logger)
            @logger = new_logger
        end
        def includingClass.logger
            if ! @logger
                return @@logger
            end
            return @logger
        end
    end
        
    public

    def self.global_logger=(new_logger)
        @@logger = new_logger
    end
    
    def self.global_logger
        @@logger
    end

	def DebugLog.log_level(log_level)
		@@logger.level = log_level
	end

    
    def warn(message)
        self.class.logger.warn('[WARN] ' + caller(1)[0] + ' ' + message)
    end

    def error(message)
        self.class.logger.error('[ERROR] ' + self.class.name + ' ' + message)
    end
    
    def info(message)
        self.class.logger.info('[INFO] '+ self.class.name + " : " + message)
    end
    
    def debug(message)
        self.class.logger.debug('[DEBUG] ' + self.class.name + " : " + message)    	
    end
    
    def logger=(newlogger)
        @logger = newlogger
    end
    
    def logger()
        @logger
    end

end