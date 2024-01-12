# gen this rather than have it as a file, because my editor will change the \r if I open and save
File.open("test/examples/crcl.test","w"){|f|
f.puts "[prog]
1\r2\r\n3\n1/0 -- see line number
[output]
1
2
3
[stderr]
4:2 (/) div 0 (DynamicError)
"
}
