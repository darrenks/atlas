require_relative "./parse2d.rb"
require_relative "./type.rb"
require_relative "./infer.rb"
require_relative "./lazylib.rb"
require_relative "./to1d.rb"

def narrow(tokens,error_stream=STDERR)
  non_uniq_roots,last_error = parse2d(tokens)
  w1d = non_uniq_roots.map{|root| [root]+to1d(root) }
  uniq_roots_w1d = w1d.uniq{|root,d1,nodes|d1}
  max_nodes = uniq_roots_w1d.map{|root,d1,nodes|nodes}.max
  max_roots = uniq_roots_w1d.select{|root,d1,nodes|nodes == max_nodes}
  roots=max_roots.partition{|root,d1,nodes|!d1.flatten.include?("zI")}
  roots.map!{|root_set|root_set.map{|root,d1,nodes|root}}

  error_stream.puts "%d valid parses, %d uniq, %d maximal" % [non_uniq_roots.size,uniq_roots_w1d.size,max_roots.size]

  without_zipi = roots[0].select{|root|
    begin
      infer(root)
      true
    rescue AtlasTypeError,InfiniteLoopError # for type value depending on self
      last_error = $!
      nil
    end
  }
  if without_zipi == []
    roots = roots[1].select{|root|
      begin
        infer(root)
        true
      rescue AtlasTypeError,DynamicError # dynamic error for type loop detection (not really dynamic)
        last_error = $!
        nil
      end
    }
  else
    roots = without_zipi
  end

  if roots.size > 1
    error_stream.puts "There are multiple type valid parses, two are:"
    roots[0,2].each{|root| error_stream.puts to1d(root)[0]*" " }
    raise
  elsif roots.size == 0
    error_stream.puts "There were no valid type parses, keep in mind that when using implicit IO it will not attempt to overwrite spaces (just explicit IO there), last error was"
    raise last_error
  end

  root = roots.flatten[0]
  root
end