# Llama Leap

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
echo ollama.generate("llama2", "How are you today?")
```

# Testing

- ensure ollama is running on the default port
  - `./ollama serve`
- run `nim c -r tests/test_llama_leap.nim`
