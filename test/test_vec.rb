require_relative '../repl.rb'

def check(expected,found,name,test)
  if expected!=found
    STDERR.puts "expecting %p found %p for %s of %p" % [expected,found,name,test]
    exit
  end
end

fn_type = create_specs({[Int]=>Int})[0]

T = TypeWithVecLevel
U = Unknown

# todo test VecOf
# what other things can gen errors? are many errors impossible?

# => zip_level, rep_level, return type
tests = {
  # [int]
  [[T.new(Int+0,0)],{[Int]=>Int}] => [0,[0],[1],"Int"],
  [[T.new(Int+0,1)],{[Int]=>Int}] => [0,[0],[0],"Int"],
  [[T.new(Int+1,0)],{[Int]=>Int}] => [0,[0],[0],"Int"],
  [[T.new(Int+1,1)],{[Int]=>Int}] => [1,[0],[0],"<Int>"],
  [[T.new(Int+2,0)],{[Int]=>Int}] => [1,[0],[0],"<Int>"],
  [[T.new(Int+2,1)],{[Int]=>Int}] => [2,[0],[0],"<<Int>>"],

  # [a]
  [[T.new(Int+0,0)],{[A]=>A}] => [0,[0],[1],"Int"],
  [[T.new(Int+0,1)],{[A]=>A}] => [0,[0],[0],"Int"],
  [[T.new(Int+1,0)],{[A]=>A}] => [0,[0],[0],"Int"],
  [[T.new(Int+1,1)],{[A]=>A}] => [1,[0],[0],"<Int>"],
  [[T.new(Int+2,0)],{[A]=>A}] => [0,[0],[0],"[Int]"],
  [[T.new(Int+2,1)],{[A]=>A}] => [1,[0],[0],"<[Int]>"],

  # [int] [int]
  [[T.new(Int+0,0),T.new(Int+0,0)],{[[Int],[Int]]=>Int}] => [0,[0,0],[1,1],"Int"],
  [[T.new(Int+2,2),T.new(Int+0,0)],{[[Int],[Int]]=>Int}] => [3,[0,3],[0,1],"<<<Int>>>"],
  [[T.new(Int+1,0),T.new(Int+1,0)],{[[Int],[Int]]=>Int}] => [0,[0,0],[0,0],"Int"],
  [[T.new(Int+2,0),T.new(Int+1,0)],{[[Int],[Int]]=>Int}] => [1,[0,1],[0,0],"<Int>"],
  [[T.new(Int+1,1),T.new(Int+1,0)],{[[Int],[Int]]=>Int}] => [1,[0,1],[0,0],"<Int>"],
  [[T.new(Int+2,1),T.new(Int+1,0)],{[[Int],[Int]]=>Int}] => [2,[0,2],[0,0],"<<Int>>"],
  [[T.new(Int+1,1),T.new(Int+1,1)],{[[Int],[Int]]=>Int}] => [1,[0,0],[0,0],"<Int>"],
  [[T.new(Int+2,1),T.new(Int+1,1)],{[[Int],[Int]]=>Int}] => [2,[0,1],[0,0],"<<Int>>"],

  # [a] [int]
  [[T.new(Int+1,0),T.new(Int+0,0)],{[[A],[Int]]=>A}] => [0,[0,0],[0,1],"Int"],
  [[T.new(Int+1,0),T.new(Int+1,0)],{[[A],[Int]]=>A}] => [0,[0,0],[0,0],"Int"],
  [[T.new(Int+1,1),T.new(Int+1,0)],{[[A],[Int]]=>A}] => [1,[0,1],[0,0],"<Int>"],
  [[T.new(Int+2,0),T.new(Int+1,0)],{[[A],[Int]]=>A}] => [0,[0,0],[0,0],"[Int]"],
  [[T.new(Int+1,0),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [1,[1,0],[0,0],"<Int>"],
  [[T.new(Int+1,1),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [1,[0,0],[0,0],"<Int>"],
  [[T.new(Int+2,0),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [1,[1,0],[0,0],"<[Int]>"],
  [[T.new(Int+2,1),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [1,[0,0],[0,0],"<[Int]>"],

  # [a] [a]
  [[T.new(Int+1,0),T.new(Int+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,1],"Int"],
  [[T.new(Int+1,0),T.new(Int+1,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"Int"],
  [[T.new(Int+0,1),T.new(Int+1,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"Int"],
  [[T.new(Int+2,0),T.new(Int+1,0)],{[[A],[A]]=>A}] => [1,[0,1],[0,0],"<Int>"],
  [[T.new(Int+2,1),T.new(Int+1,0)],{[[A],[A]]=>A}] => [2,[0,2],[0,0],"<<Int>>"],
  [[T.new(Int+2,0),T.new(Int+2,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[Int]"],
  [[T.new(Int+1,1),T.new(Int+2,0)],{[[A],[A]]=>A}] => [1,[0,0],[0,0],"<Int>"],
  [[T.new(Int+2,1),T.new(Int+2,0)],{[[A],[A]]=>A}] => [1,[0,1],[0,0],"<[Int]>"],

  # [a] [b]
  [[T.new(Int+1,0),T.new(Int+0,0)],{[[A],[B]]=>A}] => [0,[0,0],[0,1],"Int"],
  [[T.new(Int+1,0),T.new(Int+1,0)],{[[A],[B]]=>A}] => [0,[0,0],[0,0],"Int"],
  [[T.new(Int+2,0),T.new(Int+1,0)],{[[A],[B]]=>A}] => [0,[0,0],[0,0],"[Int]"],
  [[T.new(Int+2,1),T.new(Int+1,0)],{[[A],[B]]=>A}] => [1,[0,1],[0,0],"<[Int]>"],
  [[T.new(Int+2,1),T.new(Int+1,0)],{[[A],[B]]=>A}] => [1,[0,1],[0,0],"<[Int]>"],
  [[T.new(Int+2,1),T.new(Int+1,1)],{[[A],[B]]=>A}] => [1,[0,0],[0,0],"<[Int]>"],

  # Unknown tests
  # [int] would all be failures during lookup type fn

  # a
  [[T.new(U+0,0)],{[A]=>A}] => [0,[0],[0],"A"],
  [[T.new(U+1,0)],{[A]=>A}] => [0,[0],[0],"A"],
  [[T.new(U+2,0)],{[A]=>A}] => [0,[0],[0],"[A]"],
  [[T.new(U+0,0+1)],{[A]=>A}] => [1,[0],[0],"<A>"],
  [[T.new(U+0,0+2)],{[A]=>A}] => [2,[0],[0],"<<A>>"],
  [[T.new(U+2,0+2)],{[A]=>A}] => [2,[0],[0],"<<[A]>>"],

  # [a] [int]
  [[T.new(U+0,0),T.new(Int+0,0)],{[[A],[Int]]=>A}] => [0,[0,0],[0,1],"A"],
  [[T.new(U+0,0),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [1,[1,0],[0,0],"<A>"],
  [[T.new(U+2,2),T.new(Int+2,0)],{[[A],[Int]]=>A}] => [2,[0,1],[0,0],"<<[A]>>"],

  # [a] [a]
  [[T.new(U+0,0),T.new(U+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"A"],
  [[T.new(U+1,0),T.new(U+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"A"],
  [[T.new(U+2,0),T.new(U+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[A]"],
  [[T.new(U+1,0),T.new(U+1,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"A"],
  [[T.new(U+2,0),T.new(U+1,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[A]"],
  [[T.new(U+2,0),T.new(U+2,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[A]"],
  [[T.new(U+2,0),T.new(U+0,1)],{[[A],[A]]=>A}] => [1,[1,0],[0,0],"<[A]>"],

  [[T.new(U+0,0),T.new(Int+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,1],"Int"],
  [[T.new(U+1,0),T.new(Int+0,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,1],"Int"],
  [[T.new(U+2,0),T.new(Int+0,0)],{[[A],[A]]=>A}] => [1,[0,1],[0,1],"<Int>"],
  [[T.new(U+0,0),T.new(Int+1,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"Int"],
  [[T.new(U+0,0),T.new(Int+2,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[Int]"],
  [[T.new(U+2,0),T.new(Int+2,0)],{[[A],[A]]=>A}] => [0,[0,0],[0,0],"[Int]"],

  # [a] [b] todo but probably not needed

}
# tests = {tests.keys[-1] => tests[tests.keys[-1]]}

tests.each{|k,v|
  arg_types, spec = *k
  node=IR.new
  node.args = arg_types.map{|a|
    r=IR.new
    r.type_with_vec_level = a
    r.op = Op.new
    r
  }
  node.op=Op.new
  fn_type = create_specs(spec)[0]
#   begin
    t = possible_types(node, fn_type)
#   rescue #AtlasError => e
    if node.last_error
    if v != nil
      STDERR.puts "not expecting error for %p"%[k]
      raise node.last_error
    end
    next
    end
#   end
  if v == nil
    STDERR.puts "expecting error for %p"%[k]
    STDERR.puts "found %p %p %p" % [t.inspect,node.zip_level,node.rep_levels]
    exit
  end
  ez,er,ep,et = *v
  check(et,t.inspect,"type",k)
  check(ez,node.zip_level,"zip_level",k)
  check(er,node.rep_levels,"rep level",k)
  check(ep,node.promote_levels,"promote level",k)
}

puts "PASS #{tests.size} vec tests"
