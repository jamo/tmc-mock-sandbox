require 'httmultiparty'
require 'httparty'
require 'base64'
require 'json'
require "pstore"
require "byebug"

class App < Sinatra::Base
  $store =  PStore.new("results.pstore")
  get '/status.json' do
    if ENV['REAL_SANDBOX_ADDRESS']
      puts "Requesting from real sandbox"
      json(JSON.parse(HTTMultiParty.get("#{ENV['REAL_SANDBOX_ADDRESS']}/status.json").body))
    else
      puts "Returning static response for status.json"
      json({status: 'ok'})
    end
  end

  get '/' do
    json({status: 'ok'})
  end

  def force_utf8_violently(str)
    if str.encoding == Encoding.find('UTF-8') && str.valid_encoding?
      str
    else
      str.force_encoding('ISO-8859-1')
      if str.valid_encoding?
        str.encode('UTF-8')
      else
        str.force_encoding('UTF-8')
        str.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace)
      end
    end
  end

  def get_hash_for_tar(request, params)
    fail 'no file' if !params['file'] || !params['file'][:tempfile]
    hash = ""
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp(request['file'][:tempfile], File.join(tmpdir, 'submission.tar'))
      `cd #{tmpdir} && tar -xvf submission.tar`
      FileUtils.rm(File.join(tmpdir, 'submission.tar'))
      hash = `cd #{tmpdir} && find . -type f  -not -name '*.jar' -print0 | sort -z | xargs -0 cat | sha512sum`
      fail unless $?.success?
      hash.gsub!(/\s.*/, '') # drop the file name from the output
    end
    hash
  end

  post '/tasks.json' do
    p PARAMS: params
    json = {}
    hash = get_hash_for_tar(request, params)
    p HASH: hash
    elem = nil
    $store.transaction do
      elem = $store[hash]
    end

    if elem && !ENV['FORCE_UPDATE']
      json = JSON.parse(elem)
      body_json = json.merge({'token' => params['token']})
      puts "Notifying tmc-server at #{params['notify']}"
      puts "Sending tasks to real sandbox soon"
      Thread.new do
        sleep 2
        puts "Sending tasks to real sandbox now"
        puts HTTMultiParty.post(params['notify'], body: body_json)
      end
    elsif ENV['REAL_SANDBOX_ADDRESS']
      result = HTTMultiParty.post("#{ENV['REAL_SANDBOX_ADDRESS']}/tasks.json",
                                  body: {token: params['token'],
                                         notify: "http://#{request.env['SERVER_NAME']}:#{request.env['SERVER_PORT']}/#{Base64.urlsafe_encode64(JSON.generate({notify: params['notify'], hash: hash, token: params['token']}))}",
                                         file: params['file'][:tempfile]
      })
      json = JSON.parse(result.body)
    else
      puts "Nothing found for hash: #{hash}\n#{params}"
    end
    json(json)
  end

  post '/:origin' do
    puts "got submit from sandbox"
    data = JSON.parse(Base64.urlsafe_decode64(params[:origin]))
    hash = data['hash']
    notify = data['notify']
    result = params.dup
    %w(origin captures splat).each {|k| result.delete(k) }
    filtered_result = Hash[result.map do |k, v|
      [k, force_utf8_violently(v)]
    end]
    HTTMultiParty.post(notify, body: filtered_result)
    # post back and keep results
    $store.transaction do
      $store[hash] = JSON.generate(filtered_result)
      puts "stored data"
    end
    json({status: 'ok'})
  end
end
