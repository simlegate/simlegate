#!/usr/bin/env ruby

# render.rb
require 'github/markdown'

filename = File.basename(ARGV[0],'.md') 

file_content =  GitHub::Markdown.render_gfm File.read(ARGV[0])

File.open("posts/#{filename}.html",'w'){|file|file.write(file_content)}
