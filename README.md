# llama_leap

- WIP
- Nim library to work with the Ollama API

## Example

- API baseurl defaults to `http://localhost:11434/api`
- you may pass an alternate to `newOllamaAPI()`

```nim
let ollama = newOllamaAPI()
echo ollama.generate("llama2", "How are you today?")
```

## Generate

- Only the non-streaming generate API is currently supported

```nim
# simple interface
echo ollama.generate("llama2", "How are you today?")

# nim typed interface
let req = GenerateReq(
  model: "llama2",
  prompt: "How are you today?",
  system: option("Please talk like a pirate. You are longbeard the llama.")
)
let resp = ollama.generate(req)
echo "> " & resp.response

# direct json interface
let req = %*{
  "model": "llama2",
  "prompt": "How are you today?",
  "system": "Please talk like a pirate. You are longbeard the llama."
}
let resp = ollama.generate(req)
echo "> " & resp["response"].getStr
```

# Testing

- ensure ollama is running on the default port
  - `./ollama serve`
- run `nim c -r tests/test_llama_leap.nim`
