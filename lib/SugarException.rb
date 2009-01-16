class SugarException < Exception
end

class MonosaccharideException < SugarException
end

class LinkageException < SugarException
end

class SugarTraversalBreakSignal < SugarException
end