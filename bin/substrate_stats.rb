#!/usr/bin/env ruby
#
#  Created by Hiren Joshi on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

$:.push('lib')

require 'Sugar'
require 'Sugar/IO/CondensedIupac'
require 'Sugar/IO/GlycoCT'
require 'Sugar/IO/Glyde'
require 'SugarException'

Monosaccharide.Load_Definitions("data/dictionary.xml")

# We're going to do all of our work in the Glyde namespace (which is actually Glycoct)

NamespacedMonosaccharide.Default_Namespace = :glyde

require 'optparse'

OPTS = {
	:verbose => 4,
	:outfile => 'results.csv',
	:test => false,
	:sulfation => false,
	:removenacac => true,
	:analysis => [:raw]
}

VALID_ANALYSES = [:raw,:donorsubstrate,:donoronly]

verbosity = 0

ARGV.options {
  |opt|

  opt.banner = "Usage:\n\truby substrate_stats.rb [options] \n"

  opt.on("Options:\n")
  opt.on("-v", "--[no-]verbose", TrueClass, "Increase verbosity") { |verbose| OPTS[:verbose] = verbose ? (OPTS[:verbose] - 1) : (OPTS[:verbose] + 1) }
  opt.on("-h", "--help", "This text") { puts opt; exit 0 }
  opt.on("-o", "--outfile FILE", String, "Write results to file") { |OPTS[:outfile]| }
  opt.on("-t", "--test", TrueClass, "Test only (don't do anything)") { |OPTS[:test]| }
  opt.on("-s", "--[no-]sulfation", TrueClass, "Leave sulfation in residue names") { |OPTS[:sulfation]| }
  opt.on("-n", "--[no-]neuacactran", TrueClass, "Translate NeuAcAc to NeuAc") { |OPTS[:removenacac]| }
  opt.on("-a", "--analysis ANALYSISNAME", String, "Do an analysis (choose from #{VALID_ANALYSES.collect {|a| a.to_s}.join(',')})") { |name| OPTS[:analysis] << name.to_sym }
  opt.parse!

}


module Sugar::IO::GlycoCT::Builder
  
  ALIASED_NAMES = {
    'xgal-hex-1:5'            => 'dgal-hex-1:5',
    'dgal-hex-x:x'            => 'dgal-hex-1:5',
    'dgal-hex-x:x|2n-acetyl'  => 'dgal-hex-1:5|2n-acetyl',
    'dglc-hex-x:x'            => 'dglc-hex-1:5',
    'dglc-hex-x:x|6:a'        => 'dglc-hex-1:5|6:a',
    'dglc-hex-x:x|2n-acetyl'  => 'dglc-hex-1:5|2n-acetyl',
    'dman-hex-x:x'            => 'dman-hex-1:5',
    'dgro-dgal-non-x:x|1:a|2:keto|3:d|5n-acetyl'  => 'dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl'
  }
  
  if OPTS[:removenacac]
    Sugar::IO::GlycoCT::Builder::ALIASED_NAMES['dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl|9acetyl'] = 'dgro-dgal-non-2:6|1:a|2:keto|3:d|5n-acetyl'
  end
  
  alias_method :builder_factory, :monosaccharide_factory
  def monosaccharide_factory(name)
    name.gsub!(/\|\d(n-)?sulfate/,'') unless OPTS[:sulfation]
    return builder_factory(ALIASED_NAMES[name] || name)
  end
end

def mean(array)
  (array.inject(0) { |sum, x| sum += x }) / array.size.to_f
end

def mean_and_standard_deviation(array)
  m = mean(array)
  if array.size == 1
    return m, 0.0
  end
  variance = array.inject(0) { |variance, x| variance += (x - m) ** 2 }
  return m, Math.sqrt(variance/(array.size-1))
end

DebugLog.log_level(5)
count = 0
disac_count = 0

all_sibs = {}
all_parents = {}
disaccharides = Array.new()

glycoct_to_ic = {}

results = Hash.new() { |hash,key| hash[key] = { :buckets => Hash.new() { |h,k| all_sibs[k] = 1; h[k] = 0 }, :parent_buckets => Hash.new() { |h,k| all_parents[k] = 1; h[k] = 1 } } }

File.open("data/disaccharides_dump.txt","r") do |file|
  seq = ''
  while (line = file.gets)
    if (line == "---\n")
      sug = Sugar.new()
      sug.extend(Sugar::IO::GlycoCT::Builder)
      sug.extend(Sugar::IO::GlycoCT::Writer)
      sug.target_namespace = :glyde
      sug.sequence = seq
      seq = ''
      donor, substrate = sug.paths[0]
      glycoct_to_ic[donor.name] = donor.name(:ic)
      glycoct_to_ic[substrate.name] = substrate.name(:ic)
      
      disaccharides << { :donor => donor.name, :substrate => substrate.name, :anomer => donor.anomer, :posn => donor.paired_residue_position}
      sug.finish
    else
      seq += line
    end
  end
end

all_sibs["sibling"] = 1

File.open("data/human_glycosciences.dump","r") do |file|
  while (line = file.gets)
    id,sequence = line.split(/\s+/)
    sequence.gsub!(/\\n/,"\n")
    next if sequence.match(/REPEAT/)
    sug = Sugar.new()
    sug.extend(Sugar::IO::GlycoCT::Builder)
    sug.extend(Sugar::IO::CondensedIupac::Writer)
    sug.target_namespace = :ic
    begin
      sug.sequence = sequence
      disaccharides.each { |disac|
        residues = sug.composition_of_residue(disac[:substrate])
        residues.each { |res|
          child_res = res.residue_at_position(disac[:posn])
          if child_res && child_res.anomer == disac[:anomer] && child_res.name(:glyde) == disac[:donor]
            siblings = res.children.reject {|r| r[:residue] == child_res }
            if siblings.size == 0
              results[disac][:buckets]["alone"] += 1
            end
            results[disac][:buckets]["total"] += 1
            results[disac][:buckets]["sibling"] = 1 - (results[disac][:buckets]["alone"].to_f / results[disac][:buckets]["total"].to_f)
            siblings.each { |sibling|
              sib = sibling[:residue]
              link = sibling[:link]
              name = "#{sib.name(:ic)}#{sib.anomer}#{link.get_position_for(sib)}#{link.get_position_for(res)}"
              results[disac][:buckets][name] += 1
              disac_count += 1
            }
            if res.parent
              parent_name = res.parent.name(:ic).gsub!(/-ol/,'')
              results[disac][:parent_buckets][res.parent.name(:ic)] += 1
            end
            count += 1
          end
        }
      }
    rescue MonosaccharideException => err
        p err
    rescue SugarException => err
        p err
    ensure
        sug.finish
    end
  end
end
p count
p disac_count

File.open(OPTS[:outfile],"w") do |file|
  
  if OPTS[:analysis].include?(:raw)
    file << "Linkage,#{all_sibs.keys.sort.reverse.join(",")},parents,#{all_parents.keys.sort.join(",")}\n"
    results.keys.sort_by{ |d| d[:donor] }.each { |disac|
    #  puts "Link: #{disac[:donor]} (#{disac[:anomer]}x-#{disac[:posn]}) #{disac[:substrate]}"
      sibs_string = all_sibs.keys.sort.reverse.collect { |name| results[disac][:buckets][name] || 0 }.join(",")
      parents_string = all_parents.keys.sort.collect { |name| results[disac][:parent_buckets][name] || 0 }.join(",") 
      file << ["#{glycoct_to_ic[disac[:donor]]}(#{disac[:anomer]}x-#{disac[:posn]})#{glycoct_to_ic[disac[:substrate]]}",sibs_string,' ',parents_string].join(",")
      file << "\n"
    }
  end

  if OPTS[:analysis].include?(:donorsubstrate)
    compressed_buckets = Hash.new() { |h,k| h[k] = Array.new() }
    results.keys.each { |disac|
      compressed_key = glycoct_to_ic[disac[:donor]]+"-"+glycoct_to_ic[disac[:substrate]]
      compressed_buckets[compressed_key] << results[disac][:buckets]["sibling"]
    }
    file << "Disaccharide,Ave-sibs,stdev\n"
    compressed_buckets.keys.sort.each { |disac|
      file << ([disac] + mean_and_standard_deviation(compressed_buckets[disac])).join(',') + "\n"
    }
  end
  
  if OPTS[:analysis].include?(:donoronly)
    compressed_buckets = Hash.new() { |h,k| h[k] = Array.new() }
    results.keys.each { |disac|
      compressed_key = glycoct_to_ic[disac[:donor]]+"-"+disac[:anomer]+"-"+disac[:posn].to_s
      compressed_buckets[compressed_key] << results[disac][:buckets]["sibling"]
    }
    file << "Disaccharide,Ave-sibs,stdev\n"
    compressed_buckets.keys.sort.each { |disac|
      file << ([disac] + mean_and_standard_deviation(compressed_buckets[disac])).join(',') + "\n"
    }    
  end
end