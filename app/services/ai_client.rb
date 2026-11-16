# Thin wrapper around RubyLLM for all AI features (next-day planning,
# night-update parsing, roadmap reflow, email briefs). Centralises:
#   - whether AI is enabled (OPENAI_API_KEY present, legacy GROQ_API_KEY ok)
#   - the model to use
#   - asking for free text or strict JSON, with safe parsing
#
# Everything raises on failure so callers can fall back deterministically.
class AiClient
  # Default model. Override with OPENAI_MODEL (or GROQ_MODEL for legacy Groq).
  def self.model
    ENV["OPENAI_MODEL"].presence ||
      (ENV["OPENAI_API_KEY"].blank? && ENV["GROQ_MODEL"].presence) ||
      "gpt-4o-mini"
  end

  def self.enabled?
    ENV["OPENAI_API_KEY"].present? || ENV["GROQ_API_KEY"].present?
  end

  def initialize(temperature: 0.4, model: self.class.model)
    @temperature = temperature
    @model = model
  end

  def enabled?
    self.class.enabled?
  end

  # Ask for a free-text answer.
  def ask(prompt)
    chat.ask(prompt).content.to_s.strip
  end

  # Ask for JSON and parse it. Raises if no JSON object is found.
  def ask_json(prompt)
    text = chat.ask(json_instruction(prompt)).content.to_s
    json = text[/\{.*\}/m] or raise "No JSON found in AI response"
    JSON.parse(json)
  end

  private

  def chat
    c = RubyLLM.chat(model: @model, provider: :openai, assume_model_exists: true)
    c.with_temperature(@temperature)
    c
  end

  def json_instruction(prompt)
    "#{prompt}\n\nRespond with ONLY valid minified JSON, no prose, no code fences."
  end
end
