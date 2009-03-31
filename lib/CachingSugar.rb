module CachingSugar
#  CACHED_METHODS = [:residue_composition,:get_path_to_root, :get_sugar_to_root,:get_sugar_from_residue,:get_attachment_point_path_to_root,:depth]
  CACHED_METHODS = [:residue_composition,:get_path_to_root,:get_sugar_to_root,:get_sugar_from_residue,:depth,:paths]
#  CACHED_METHODS = [:residue_composition]
  
  def self.extend_object(sug)
    sug.residue_composition.each { |res|
      res.extend(CachedMonosaccharide) unless res.is_a?(CachedMonosaccharide)
      res.parent_sugar = sug
    }

    CACHED_METHODS.each { |meth_name|
      meth = sug.method(meth_name)
      wrapped_name = ("_sugar_cache_"+meth_name.to_s).to_sym
      wrapper = Proc.new do |*args_a|
        target_res = args_a[0] || @root
        if cached_results[target_res.object_id].has_key?(meth_name)
          debug("Cached #{meth_name} on #{self.object_id} with argument #{target_res.object_id}")
          cached_results[target_res.object_id][meth_name]
        else
          debug("Un-cached #{meth_name} on #{self.object_id} with argument #{target_res.object_id}")
          cached_results[target_res.object_id][meth_name] = meth.call(*args_a)
          cached_results[target_res.object_id][meth_name]
        end
      end

      class << sug; self end.send(:alias_method, wrapped_name, meth_name)
      class << sug; self end.send(:define_method, meth_name, wrapper)
      
      sug.debug("Redefining #{meth_name} to #{wrapped_name}")
      sug.debug("Setting #{meth_name}")      
    }
    
    
    class << sug
      alias_method :uncached_monosaccharide_factory, :monosaccharide_factory
      alias_method :uncached_deep_clone, :deep_clone
      attr_accessor :cached_results
    end

    sug.debug("Setting cached results on #{sug.object_id}")
    sug.cached_results = Hash.new() { |h,k| h[k] = Hash.new() }
    sug.debug("Cached results now set for #{sug.object_id}")
    super
  end

  def monosaccharide_factory(prototype)
    mono = uncached_monosaccharide_factory(prototype)
    mono.extend(CachedMonosaccharide) unless mono.is_a?(CachedMonosaccharide)
    mono.parent_sugar = self
    mono
  end

  def delete_all_cached_results(residue)
    cached_results[residue.object_id] = Hash.new()
  end

  def deep_clone
    sug = super
    sug.cached_results = Hash.new() { |h,k| h[k] = Hash.new() }
    sug
  end

  module CachedMonosaccharide

    def self.extend_object(res)

      class << res
        alias_method :uncached_add_child, :add_child
        alias_method :uncached_remove_child, :remove_child
      end
      
      super
    end
    
    attr_accessor :parent_sugar
    
    def add_child(mono,linkage)
      debug("Invalidating all parents of #{mono.object_id}")
      parent_sugar.delete_all_cached_results(self)
      parent_sugar.get_path_to_root(self).each { |r|
        debug("Invalidating a parent #{r.object_id}")
        parent_sugar.delete_all_cached_results(r)
      }
      uncached_add_child(mono,linkage)
    end
    
    def remove_child(mono)
      debug("Invalidating all children of #{mono.object_id}")
      parent_sugar.delete_all_cached_results(mono)
      parent_sugar.residue_composition(mono).each { |r|
        debug("Invalidating a child #{r.object_id}")
        parent_sugar.delete_all_cached_results(r)
      }
      parent_sugar.get_path_to_root(self).each { |r|
        debug("Invalidating a parent #{r.object_id}")
        parent_sugar.delete_all_cached_results(r)
      }
      debug("Invalidating a residue #{self.object_id}")
      parent_sugar.delete_all_cached_results(self)
      uncached_remove_child(mono)
    end
    
  end
  
end