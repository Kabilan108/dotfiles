{
  hostName = "";
  enableNvidia = false;
  env = rec {
    WALLPAPER = "";

    # config opts for 3rd party tools
    FZF_DEFAULT_OPTS = "--reverse";
    GTK_THEME = "WhiteSur-Dark";
    UV_LINK_MODE = "copy";
    UV_SYSTEM_PYTHON = 1;

    # my tools
    DIFFGPT_API_KEY = "";
    DIFFGPT_BASE_URL = "https://openrouter.ai/api/v1/";
    DIFFGPT_MODEL = "openai/gpt-4o-mini";
    PYREPL_PORT = 5678;
    SIREN_API_KEY = "";

    # data dirs
    USER_DATA = "/vault/userdata";
    FASTAI_HOME = "${USER_DATA}/fastai";
    GOPATH = "${USER_DATA}/go";
    HF_HOME = "${USER_DATA}/huggingface";
    HF_DATASETS_CACHE = "$HF_HOME/datasets";
    LLM_USER_PATH = "${USER_DATA}/datasette-llm";
    OLLAMA_MODELS = "${USER_DATA}/ollama/models";
    TORCH_HOME = "${USER_DATA}/torch";

    # llms
    ANTHROPIC_API_KEY = "";
    GEMINI_API_KEY = "";
    GROQ_API_KEY = "";
    OPENAI_API_KEY = "";
    OPENROUTER_API_KEY = "";
    PERPLEXITY_API_KEY = "";
    DEEPSEEK_API_KEY = "";
  };
}
