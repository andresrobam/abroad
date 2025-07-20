class Conversation
  attr_reader :language, :messages
  def initialize(language, message)
    @language = language
    @messages = [message]
  end
end

class Message
  attr_reader :author, :text, :api_id
  def initialize(author, text, api_id = nil)
    @author = author
    @text = text
    @api_id = api_id
  end
  def to_hash()
    { author: author, text: text }
  end
end

class Mission
  attr_reader :title, :prompt
  def initialize(title, prompt)
    @title = title
    @prompt = prompt
  end
end

missions = [
  Mission.new("Eating at a restaurant", "I was just seated at a restaurant and you are the waiter."),
  Mission.new("Pharmacy", "I just entered a pharmacy looking to buy some medicine and you are behind the counter."),
  Mission.new("Cheese store", "I just entered a cheesemonger and am looking at the different cheeses in the store and you work there."),
  Mission.new("Craft beer bar", "I just entered a craft beer bar and walked up to the counter looking to place an order.")
]

def starting_prompt(language, mission)
<<-PROMPT
My goal is to learn #{language}.

I want you to be my tutor, but do it via conversation. Start the conversation by talking very simple #{language} and start using more complex words and grammar as we go along. If at any point it seems like I'm struggling, turn down the difficulty a bit and let me recover. If I seem to struggle too much, you can help me along or even explain things to me in simpler #{language}. Once it seems I have recovered and am keeping up with the difficulty level, start increasing it again. Don't ever call yourself ChatGPT, pretend to be a real person.

Never under any circumstances use a different language other than #{language}.
#{mission != nil ? 'The conversation should follow this scenario: '+mission.prompt : 'Start the conversation now.'}
PROMPT
end

def help_prompt(conversation, index, question)
  log = conversation.messages[1, index+1].map { |message| "<msg:#{message.author}>#{message.text}</msg>"}
<<-PROMPT
"I am sending you a transcript of a conversation of me talking to my #{conversation.language} tutor. The conversation is in an XML-like format, with the whole conversation being wrapped in a <conv> block and individual messages wrapped either <msg:tutor> blocks for messages coming from the tutor and <msg:user> blocks for messages coming from me. After the <conv> block there is a question about the last message in the conversation. The question is wrapped in a <question> block. I want you to answer the question.
<conv>#{log}</conv>
<question>#{question}</question>"
PROMPT
end


require 'sinatra'
require 'json'
require 'securerandom'
require_relative 'openai'

conversations = {}

get '/missions' do
  content_type :json
  missions.map(&:title).to_json
end

post '/start' do
  language = params[:language]
  mission = missions[params[:mission].to_i]
  conversation = Conversation.new(language, Message.new('user', starting_prompt(language, mission)))
  id = SecureRandom.uuid
  conversations[id] = conversation
  OpenAI.converse(conversation)
  { id: id, message: conversation.messages.last.to_hash}.to_json
end

post '/chat' do
  conversation = conversations[params[:conversation]]
  conversation.messages << Message.new('user', params[:text])
  OpenAI.converse(conversation)
  conversation.messages.last.to_hash.to_json
end

post '/ask' do
  conversation = Conversation.new(language, Message.new('user', 
                                                        help_prompt(conversations[params[:conversation]], 
                                                                    params[:message].to_i + 1, 
                                                                    params[:question])))
  id = SecureRandom.uuid
  conversations[id] = conversation
  OpenAI.converse(conversation)
  { id: id, message: conversation.messages.last.to_hash}.to_json
end

=begin
puts "What language do you want learn?"
language = ""
while language.strip == ""
  language = gets
end

puts "Here are the available missions:"
missions.each_with_index do |mission, index|
  puts "#{index+1}: #{mission.title}"
end
puts "Enter the number:"

mission = nil
while mission == nil
  number = gets
  number.strip!
  begin
    number = Integer(number)
    if number < 1 or number > missions.length
      puts "Invalid number! Try again:"
    else
      mission = missions[number-1]
    end
  rescue ArgumentError, TypeError
    puts "Not a number! Try again:"
  end
end

puts "You chose: #{mission.title}"
require_relative 'openai'
conversation = Conversation.new(language, Message.new('user', starting_prompt(language, mission)))

loop do
  puts "-----"
  OpenAI.converse(conversation)
  puts(conversation.messages.last.text)
  conversation.messages << Message.new('user', gets)
end
=end
