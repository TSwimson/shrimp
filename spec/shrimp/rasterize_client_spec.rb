# encoding: UTF-8
require 'spec_helper'
require 'base64'
base64_encoded_pdf = 'JVBERi0xLjQKMSAwIG9iago8PAovVGl0bGUgKP7/KQovQ3JlYXRvciAo/v8p'

describe Shrimp::RasterizeClient do
  it 'turns an html file into a pdf' do
    15.times do
      client = Shrimp::RasterizeClient.new('file://' + File.expand_path('../test_file.html', __FILE__), {}, {}, 'out.pdf')
      client.run
      expect(Base64.encode64(File.open(File.expand_path('../../../out.pdf', __FILE__), 'rb', &:read))).to start_with(base64_encoded_pdf)
      FileUtils.rm(File.expand_path('../../../out.pdf', __FILE__))
    end
    Shrimp.server.stop
  end
end
