require 'httparty'
require 'json'

module OpenAI
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  headers 'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{ENV['OPENAI_API_KEY']}"

  def self.converse(conversation)
    body = { model: 'gpt-4.1', input: conversation.messages.last.text}
    if conversation.messages.length >= 2 
        body['previous_response_id'] = conversation.messages[-2].api_id
    end
    response = post('/responses', body: body.to_json).parsed_response
    conversation.messages << Message.new('tutor', response['output'].first['content'].first['text'], response['id'])
  end
end

