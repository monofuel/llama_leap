import curly

## ollama API Interface
## https://github.com/jmorganca/ollama/blob/main/docs/api.md

type
  OllamaAPI* = ref object
    curlPool: CurlPool
    url: string
    curlTimeout: float32

proc newOllamaAPI*(
    url: string = "http://localhost:11434/api",
    curlPoolSize: int = 4,
    curlTimeout: float32 = 10000
): OllamaAPI =
  result = OllamaAPI()
  result.curlPool = newCurlPool(curlPoolSize)
  result.url = url
  result.curlTimeout = curlTimeout

proc close*(api: OllamaAPI) =
  api.curlPool.close()
