import llama_leap

let ollama = newOllamaAPI()
echo ollama.generate("llama2", "How are you today?")
