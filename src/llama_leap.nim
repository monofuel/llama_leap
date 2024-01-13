import curly, jsony, std/[strutils, json, options, strformat, os]

## ollama API Interface
## https://github.com/jmorganca/ollama/blob/main/docs/api.md

## model parameters: https://github.com/jmorganca/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values

type
  OllamaAPI* = ref object
    curlPool: CurlPool
    baseUrl: string
    curlTimeout: float32
  GenerateReq* = ref object
    model*: string
    prompt*: string
    images*: Option[seq[string]]  # list of base64 encoded images
    format*: Option[string]       # optional format=json for a structured response
    options*: Option[JsonNode]    # bag of model parameters
    system*: Option[string]       # override modelfile system prompt
    template_str*: Option[string] # override modelfile template
    context*: Option[seq[int]]    # conversation encoding from a previous response
    stream: Option[bool]          # stream=false to get a single response
    raw*: Option[bool]            # use raw=true if you are specifying a fully templated prompt
  GenerateResp* = ref object
    model*: string
    created_at*: string
    response*: string
    done*: bool # always true for stream=false
    context*: seq[int]
    total_duration*: int
    load_duration*: int
    prompt_eval_count*: int
    prompt_eval_duration*: int
    eval_count*: int
    eval_duration*: int

proc renameHook*(v: var GenerateReq, fieldName: var string) =
  ## `template` is a special keyword in nim, so we need to rename it during serialization
  if fieldName == "template":
    fieldName = "template_str"
proc dumpHook*(v: var GenerateReq, fieldName: var string) =
  if fieldName == "template_str":
    fieldName = "template"

proc newOllamaAPI*(
    baseUrl: string = "http://localhost:11434/api",
    curlPoolSize: int = 4,
    curlTimeout: float32 = 10000
): OllamaAPI =
  ## Initialize a new Ollama API client
  result = OllamaAPI()
  result.curlPool = newCurlPool(curlPoolSize)
  result.baseUrl = baseUrl
  result.curlTimeout = curlTimeout

proc close*(api: OllamaAPI) =
  api.curlPool.close()


proc generate*(api: OllamaAPI, req: GenerateReq): GenerateResp =
  ## typed interface for /api/generate
  let url = api.baseUrl / "/generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req.stream = option(false)

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama generate failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, GenerateResp)

proc generate*(api: OllamaAPI, model: string, prompt: string): string =
  ## simple interface for /api/generate
  let req = GenerateReq(model: model, prompt: prompt)
  let resp = api.generate(req)
  result = resp.response

proc generate*(api: OllamaAPI, req: JsonNode): JsonNode =
  ## direct json interface for /api/generate
  ## only use if there are specific new features you need or know what you are doing
  let url = api.baseUrl / "/generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req["stream"] = newJBool(false)

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama generate failed: {resp.code} {resp.body}")
  result = fromJson(resp.body)
