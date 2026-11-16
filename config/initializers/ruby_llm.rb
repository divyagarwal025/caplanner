# AI configuration for the planner. Uses OpenAI via RubyLLM.
#
# Set OPENAI_API_KEY to enable the AI features (next-day planning, night-update
# parsing, roadmap reflow, and AI-written email briefs). Without it, the app
# falls back to deterministic rule-based behaviour everywhere.
#
# Legacy GROQ_API_KEY is still honoured as a fallback so existing setups keep
# working (Groq is OpenAI-API-compatible).
api_key  = ENV["OPENAI_API_KEY"].presence || ENV["GROQ_API_KEY"].presence
api_base = ENV["OPENAI_API_BASE"].presence ||
           (ENV["GROQ_API_KEY"].present? ? ENV.fetch("GROQ_API_BASE", "https://api.groq.com/openai/v1") : nil)

if api_key.present?
  RubyLLM.configure do |config|
    config.openai_api_key  = api_key
    config.openai_api_base = api_base if api_base
    config.request_timeout = 30
  end
end
