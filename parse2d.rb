require_relative "./ast.rb"

# todo can remove some bounds checking now that we surround with spaces

def parse2d(tokens,error_stream=STDERR)
  tokens,pads = surround_with_spaces(tokens)

  inputs = []
  outputs = []
  total_in_count = total_out_count = 0
  each_uniq_token(tokens){|t|
    inputs << t if t.token.str=="I"
    outputs << t if t.token.str=="O"
    total_in_count += t.narg
    total_out_count += t.nret
  }

  if outputs.size > 1
    draw_connections(tokens,error_stream)
    raise "there must be only 1 output"
  end

  implicit_output = false
  if outputs.size == 0
    total_in_count += 1
    implicit_output = true
  end

  implicit_input = false
  if total_in_count > total_out_count
    total_out_count += 1
    implicit_input = true
  end

  if total_in_count != total_out_count
    raise "total in counts != total out counts (%d %d)" % [total_in_count, total_out_count]
  end

  asts = []
  if implicit_input
    pads.each{|ti|
      origi = tokens[ti.y][ti.x]
      input = create_input(ti.x,ti.y)
      tokens[ti.y][ti.x] = input
      nest(tokens,asts,implicit_output,pads,outputs,error_stream,ti)
      tokens[ti.y][ti.x] = origi
    }
    pads.each{|ti|
      origi = tokens[ti.y][ti.x]
      input = create_zipped_input(ti.x,ti.y)
      tokens[ti.y][ti.x] = input
      nest(tokens,asts,implicit_output,pads,outputs,error_stream,ti)
      tokens[ti.y][ti.x] = origi
    }
  else
    nest(tokens,asts,implicit_output,pads,outputs,error_stream,nil)
  end

  [asts,$last_error]
end

def nest(tokens,asts,implicit_output,pads,outputs,error_stream,ti)
  if implicit_output
    pads.each{|t|
      next if t==ti
      orig = tokens[t.y][t.x]
      output = create_output(t.x,t.y)
      tokens[t.y][t.x] = output
      begin
        asts.concat parse_h(tokens,output,error_stream)
      rescue ParseError
      end
      tokens[t.y][t.x] = orig
    }
  else
    begin
      asts.concat parse_h(tokens,outputs[0],error_stream)
    rescue ParseError
    end
  end
  asts
end

def parse_h(tokens,output,error_stream)
  each_uniq_token(tokens){|t| t.ins=[]; t.outs=[] }
  each_uniq_token(tokens){|t| connect_arrow_outs(tokens,t) }

  solutions = []
  solve(tokens, solutions)

  solutions.map{|solution|
    set_edges(tokens,solution)
    #draw_connections(tokens,STDERR)

    each_uniq_token(tokens){|t|t.ast_memo = nil}
    each_uniq_token(tokens){|t|order_arg(t)}
    each_uniq_token(tokens){|t|inline_jumps(t)}

    to_ast(output)
  }
end

def surround_with_spaces(tokens)
  pads = []
  each_uniq_token(tokens){|t|
    t.token.char_no += 1
    t.token.line_no += 1
  }
  tokens = [[]]+tokens+[[]]
  tokens = tokens.map.with_index{|row,y|
    max_neighbor = [tokens[y-1].size,(tokens[y+1]||[]).size].max
    lpad = create_space(0,y)
    rpads = [1,max_neighbor-row.size].max.times.map{|x|create_space(x+row.size+1,y)}
    (pads << lpad).concat rpads
    [lpad] + row + rpads
  }
  [tokens,pads]
end

def create_space(x,y)
  Op2d.new(sym:"space",narg:0,nret:0,token:Token.new(" ",x,y))
end
def create_output(x,y)
  Ops["O"].dup.tap{|t| t.token = Token.new("O",x,y) }
end
def create_input(x,y)
  Ops["I"].dup.tap{|t| t.token = Token.new("I",x,y) }
end
def create_zipped_input(x,y)
  # make it [!I] so that it is size 1 for adjacency purposes, a nasty hack
  Ops["zI"].dup.tap{|t| t.token = Token.new(["zI"],x,y) }
end

def each_uniq_token(tokens)
  last=nil
  tokens.each{|row|
    row.each{|col|
      yield(col) unless col.equal?(last)
      last = col
    }
  }
end

def follow_forced(tokens)
  $fork_options = []
  each_uniq_token(tokens){|t| lookat(tokens, t) }
end

def try_all_options(froms,tos)
  tried_something = false
  if tos.size == 1
    to=tos[0]
    froms.combination(to.narg - to.ins.size){|selected_froms|
      selected_froms.each{|from|
        if can_connect(from,to)
          connect(from, to)
          yield
        end
      }
    }
  else
    raise "internal error" if froms.size != 1
    from=froms[0]
    tos.combination(from.nret - from.outs.size){|selected_tos|
      selected_tos.each{|to|
        if can_connect(from,to)
          connect(from, to)
          yield
        end
      }
    }
  end
  tried_something
end

def copy_edges(tokens)
  outs_bak = tokens.map{|row|row.map{|col|col.outs}}
  ins_bak = tokens.map{|row|row.map{|col|col.ins}}
  [outs_bak,ins_bak]
end

def set_edges(tokens,edges)
  outs_bak,ins_bak = edges
  #restore
  tokens.zip(outs_bak,ins_bak){|t_row,o_row,i_row|
    t_row.zip(o_row,i_row){|t,o,i|
      t.outs = o
      t.ins = i
    }
  }
end

def solve(tokens, solutions)
  follow_forced(tokens)

  edges = copy_edges(tokens)
  $fork_options.each {|froms,tos|
    tried = false
    try_all_options(froms,tos) {
      begin
        tried = true
        solve(tokens, solutions)
      rescue ParseError
        # try next choice
      end

      set_edges(tokens,edges)
    }
    return if tried
  }

  solutions << copy_edges(tokens)
  return
end

class Op
  attr_accessor :ins
  attr_accessor :outs
  attr_accessor :ast_memo
  def x
    token.char_no
  end
  def y
    token.line_no
  end
end
class Op2d # todo so bad
  attr_accessor :ins
  attr_accessor :outs
  attr_accessor :ast_memo
  def x
    token.char_no
  end
  def y
    token.line_no
  end
end


def replace(a,t,u)
  a.map{|v|
    if [v.x,v.y]==[t.x,t.y]
      u
    else
      v
    end
  }
end

def inline_jumps(t)
  if t.token.str == "#"
    out_d1 = find_direction(t.outs[0].x-t.x,t.outs[0].y-t.y)
    in_d1  = find_direction(t.x-t.ins[0].x,t.y-t.ins[0].y)
    if out_d1 != in_d1
      t.ins = t.ins.reverse
    end

    i1,i2=*t.ins
    o1,o2=*t.outs

    i1.outs = replace(i1.outs,t,o1)
    i2.outs = replace(i2.outs,t,o2)
    o1.ins = replace(o1.ins,t,i1)
    o2.ins = replace(o2.ins,t,i2)
  end
end

N = 0
E = 1
S = 2
W = 3
ArrowToDirection = {"<"=>W, ">"=>E, "^"=>N, "v"=>S}
Directions = [[0,-1],[1,0],[0,1],[-1,0]]

def draw_connections(g,error_stream)
  # todo bug if multiline tokens...
  g.each.with_index{|line,y|
    skip = 0
    line.each.with_index{|t,x|
      if skip<=0
        error_stream.print t.token.str + "&" * (t.token.str.size-1)
        skip = t.token.str.size-1
        if t.outs && t.outs.any?{|to|to.x > x && to.y==t.y}
          error_stream.print ">"
        elsif t.ins && t.ins.any?{|to|to.x == x+1}
          error_stream.print "<"
        else
          error_stream.print " "
        end
      else
        skip -= 1
      end
    }
    error_stream.puts

    line.each.with_index{|t,x|
      if t.outs && t.outs.any?{|to|to.y == y+1 && to.x==x}
        error_stream.print "v"
      elsif t.ins && t.ins.any?{|to|to.y == y+1}
        error_stream.print "^"
      else
        error_stream.print " "
      end
      error_stream.print " "
    }
    error_stream.puts
  }
end

def lookat(g,t)
  lookat_inputs(g,t)
  lookat_outputs(g,t)
end

def lookat_outputs(g,t)
  # find outgoing connections
  needed_outputs = t.nret - t.outs.size
  if needed_outputs > 0
    adjacent_inputtable = adjacents(g,t).select{|n|can_connect(t,n)}.uniq # todo this is relying on struct properties that could be circular?
    if needed_outputs > adjacent_inputtable.size
      raise $last_error=ParseError.new("op has more outputs than neighbors can input", t.token) # todo fail sooner
    elsif needed_outputs == adjacent_inputtable.size
      adjacent_inputtable.map{|to|
        connect(t,to)
      }
      # for now check more than is needed
      (adjacents(g,t)+adjacent_inputtable.map{|to| adjacents(g,to) }.flatten).each{|n|lookat(g,n)}
    else
      $fork_options << [[t],adjacent_inputtable]
    end
  end
end

def lookat_inputs(g,t) # dual of lookat_outputs (todo unduplicate code?)
  # find incoming connections
  needed_inputs = t.narg - t.ins.size
  if needed_inputs > 0
    adjacent_outputtable = adjacents(g,t).select{|n|can_connect(n,t)}.uniq
    if needed_inputs > adjacent_outputtable.size
      raise $last_error=ParseError.new("op has more inputs than neighbors can output", t.token)
    elsif needed_inputs == adjacent_outputtable.size
      adjacent_outputtable.map{|from|
        connect(from,t)
      }
      # for now check more than is needed
      (adjacents(g,t)+adjacent_outputtable.map{|from| adjacents(g,from) }.flatten).each{|n|lookat(g,n)}
    else
      $fork_options << [adjacent_outputtable,[t]]
    end
  end
end

def can_connect(from,to)
  # these may be redundant in some cases
  return false if !can_input(to)
  return false if !can_output(from)

  # # cannot have two inputs/outputs in straight line
  return false if to.token.str=="#" && to.ins.size==1 &&
    find_direction(to.x-from.x,to.y-from.y) ==
    find_direction(to.ins[0].x-to.x,to.ins[0].y-to.y)
  return false if from.token.str=="#" && from.outs.size==1 &&
    find_direction(to.x-from.x,to.y-from.y) ==
    find_direction(from.x-from.outs[0].x,from.y-from.outs[0].y)

  can_input(to) && can_output(from) &&
    # and not already connected in either way
    !(to.ins+to.outs).any?{|t|[t.x,t.y] == [from.x,from.y]}
end

def can_input(to)
  to.narg - to.ins.size > 0
end

def can_output(from)
  from.nret - from.outs.size > 0
end

def adjacents(tokens,node)
  x=node.x
  y=node.y
  size = node.token.str.size
  #todo bug with multiline strs
  result = []
  result.concat get_relative_sq(tokens,x,y,W)
  result.concat get_relative_sq(tokens,x+size-1,y,E)
  size.times.map{|i|
    result.concat get_relative_sq(tokens,x+i,y,N)
    result.concat get_relative_sq(tokens,x+i,y,S)
  }
  result
end

def connect(from,to)
  to.ins += [from]
  from.outs += [to]
end

def connect_arrow_outs(tokens,from)
  x=from.x
  y=from.y
  d = ArrowToDirection[from.token.str]
  if d
    dx,dy=*Directions[d]
    to = tokens[y+dy][x+dx]
    if to.narg - to.ins.size > 0
      connect(from,to)
    else
      raise ParseError.new("arrow pointing to token that can't take more inputs", from.token)
    end
  end
end

def get_relative_sq(tokens,x,y,d)
  dx,dy = *Directions[d]
  nx=x+dx
  ny=y+dy
  if nx<0 || ny<0 || ny>=tokens.size || nx>=tokens[ny].size
    []
  else
    [tokens[ny][nx]]
  end
end

def find_direction(dx,dy)
  if dy==0
    dx > 0 ? E : W
  else # dx==0
    dy<0 ? N : S
  end
end

def order_arg(t)
  x=t.x
  y=t.y
  if t.ins.size > 1
    out = t.outs[0]
    new_order = []
    # find out direction, then order in args relative to that
    out_d = find_direction(out.x-x,out.y-y)
    t.ins = t.ins.sort_by{|i|
      (find_direction(i.x-x,i.y-y)-out_d) % 4
    }
  end
end

def to_ast(t)
  nodes = []
  ret = to_ast_h(t,nodes)
  nodes.each{|node|node.ast_memo = nil}
  ret
end

def to_ast_h(t,nodes)
  return t.ast_memo if t.ast_memo
  return to_ast_h(t.ins[0],nodes) if %w'< > ^ v .'.include? t.token.str
  nodes << t
  t.ast_memo = n = AST.new(t,[]) # important that this sets ast_memo before recursing for args so ast_memo can prevent infinite loops
  if Array === n.op.str # undo hack from earlier that made !I 1 char
    n.op = n.op.dup
    n.op.token = n.op.token.dup
    n.op.token.str = n.op.str[0]
  end
  n.args.concat(t.ins.map{|i|to_ast_h(i,nodes)})
  n
end
