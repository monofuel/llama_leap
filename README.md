# llama_leap

- Nim library to work with the Ollama API

## Example

- API baseurl defaults to `http://localhost:11434/api`
- you may pass an alternate to `newOllamaAPI()`

```nim
import llama_leap

let ollama = newOllamaAPI()
echo ollama.generate("llama2", "How are you today?")
```

## Generate

- Only the non-streaming generate API is currently supported
  - streaming is coming soon (TM)

```nim
# simple interface
echo ollama.generate("llama2", "How are you today?")

# structured interface
let req = GenerateReq(
  model: "llama2",
  prompt: "How are you today?",
  options: option(ModelParameters(
    temperature: option(0.0f),
  )),
  system: option("Please talk like a pirate. You are Longbeard the llama.")
)
let resp = ollama.generate(req)
echo "> " & resp.response
```

## Chat

```nim
let req = ChatReq(
  model: "llama2",
  messages: @[
    ChatMessage(
      role: "system",
      content: "Please talk like a pirate. You are Longbeard the llama."
  ),
  ChatMessage(
    role: "user",
    content: "How are you today?"
  ),
],
  options: option(ModelParameters(
    temperature: option(0.0f),
    seed: option(42)
  ))
)
let resp = ollama.chat(req)
echo "> " & resp.message.content.strip()
```

## Pull

```nim
ollama.pullModel("llama2")
```

## Embeddings

```nim
let resp = ollama.generateEmbeddings("llama2", "How are you today?")
echo "Embedding Length: " & $resp.embedding.len
```

# Testing

- ensure ollama is running on the default port
  - `./ollama serve`
- run `nimble test`

## Related Repos

- [llama_leap](https://github.com/monofuel/openai_leap) is a Nim client for the OpenAI API.
- [vertex_leap](https://github.com/monofuel/vertex_leap) is a client for Google's VertexAI API.
- [mono_llm](https://github.com/monofuel/mono_llm) is a higher-level Nim library that creates a unified interface for OpenAI, Ollama, and VertexAI.
