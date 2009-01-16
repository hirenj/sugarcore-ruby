module ChameleonResidue
  attr_accessor :real_name

  def alternate_name(namespace)
    return name(namespace)
  end

  def name(namespace=nil)
    if namespace.is_a? Symbol
      namespace = NamespacedMonosaccharide::NAMESPACES[namespace]
    end
    return real_name
    # if namespace == NamespacedMonosaccharide::NAMESPACES[:ic]
    #   return real_name
    # else
    #   return 'nil'
    # end
  end

end


module Sugar::IO::CondensedIupac::Builder

  HIDDEN_RESIDUES = {    
  }

  alias_method :builder_factory, :monosaccharide_factory

  def monosaccharide_factory(name)
    begin
      my_res = builder_factory(name)
    rescue Exception => e
      my_res = builder_factory('Nil')
      my_res.extend(ChameleonResidue)
      my_res.real_name = name
      HIDDEN_RESIDUES[name] = true
    end
    
    return my_res
  end
end


module Sugar::IO::GlycoCT::Builder
  
  ALIASED_NAMES = {
    'xgal-hex-1:5'            => 'dgal-hex-1:5',
    'xgal-hex-1:5|2n-acetyl'  => 'dgal-hex-1:5|2n-acetyl',
    'dgal-hex-x:x'            => 'dgal-hex-1:5',
    'dgal-hex-x:x|2n-acetyl'  => 'dgal-hex-1:5|2n-acetyl',
    'dglc-hex-x:x'            => 'dglc-hex-1:5',
    'dglc-hex-x:x|2amino'     => 'dglc-hex-1:5|2amino',
    'dglc-hex-x:x|6:a'        => 'dglc-hex-1:5|6:a',
    'dglc-hex-x:x|2n-acetyl'  => 'dglc-hex-1:5|2n-acetyl',
    'dman-hex-x:x'            => 'dman-hex-1:5',
    'dxyl-pen-x:x'            => 'dxyl-pen-1:5',
    'lido-hex-x:x|6:a'        => 'lido-hex-1:5|6:a',
    'lgal-hex-x:x|6:d'        => 'lgal-hex-1:5|6:d',
    'dgro-dgal-non-x:x|1:a|2:keto|3:d|5n-acetyl'  => 'dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl'
  }
  
#  Sugar::IO::GlycoCT::Builder::ALIASED_NAMES['dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl|9acetyl'] = 'dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl'
  
  HIDDEN_RESIDUES = {    
  }
  
  alias_method :builder_factory, :monosaccharide_factory
  def monosaccharide_factory(name)
    name.gsub!(/\|[\du](n-)?sulfate/,'')
    name.gsub!(/\|[\du]phosphate/,'')
    name.gsub!(/\|[\du]methyl/,'')
    name.gsub!(/^o-/,'')
    name.gsub!(/\|1:aldi/,'')
    name.gsub!(/0\:0/,'x:x')
    my_res = nil
    begin
      my_name = ALIASED_NAMES[name] || name
      my_res = builder_factory("#{my_name}")
    rescue Exception => e
      my_res = builder_factory('nil')
      my_res.extend(ChameleonResidue)
      my_res.real_name = name
      HIDDEN_RESIDUES[name] = true
    end
    
    return my_res
  end
end