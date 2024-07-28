## ollama tools test
## Ensure that ollama is running!

import
  std/[unittest, json, tables, options, strutils],
  llama_leap, jsony

# Must use a tools compatible model!
const
  TestModel = "llama3.1:8b"

proc getFlightTimes(departure: string, arrival: string): string =
  var flights = initTable[string, JsonNode]()

  flights["NYC-LAX"] = %* {"departure": "08:00 AM", "arrival": "11:30 AM", "duration": "5h 30m"}
  flights["LAX-NYC"] = %* {"departure": "02:00 PM", "arrival": "10:30 PM", "duration": "5h 30m"}
  flights["LHR-JFK"] = %* {"departure": "10:00 AM", "arrival": "01:00 PM", "duration": "8h 00m"}
  flights["JFK-LHR"] = %* {"departure": "09:00 PM", "arrival": "09:00 AM", "duration": "7h 00m"}
  flights["CDG-DXB"] = %* {"departure": "11:00 AM", "arrival": "08:00 PM", "duration": "6h 00m"}
  flights["DXB-CDG"] = %* {"departure": "03:00 AM", "arrival": "07:30 AM", "duration": "7h 30m"}

  let key = (departure & "-" & arrival).toUpperAscii()
  if flights.contains(key):
    return $flights[key]
  else:
    raise newException(ValueError, "No flight found for " & key)

suite "ollama tools":
  var ollama: OllamaAPI

  setup:
    ollama = newOllamaAPI()
  teardown:
    ollama.close()

  suite "version":
    test "version":
      echo "> " & ollama.getVersion()
  suite "pull":
    test "pull model":
      ollama.pullModel(TestModel)
  
  suite "flight times":
    test "getFlightTimes":
      echo getFlightTimes("NYC", "LAX")

    test "tool call queries":
      var messages = @[
        ChatMessage(
          role: "user",
          content: option("What is the flight time from New York (NYC) to Los Angeles (LAX)?")
        )
      ]

      let firstRequest = ChatReq(
        model: TestModel,
        messages: messages,
        tools: @[
          Tool(
            `type`: "function",
            function: ToolFunction(
              name: "get_flight_times",
              description: "Get the flight times between two cities",
              parameters: ToolFunctionParameters(
                `type`: "object",
                required: @["departure", "arrival"],
                properties: %* {
                  "departure": {
                    "type": "string",
                    "description": "The departure city (airport code)"
                  },
                  "arrival": {
                    "type": "string",
                    "description": "The arrival city (airport code)"
                  }
                }
              )
            )
          )
        ]
      )

      let toolResp = ollama.chat(firstRequest)
      # add the model response to conversation history
      messages.add(toolResp.message)

      assert toolResp.message.tool_calls.len != 0
        
      # process the function call
      assert toolResp.message.tool_calls.len == 1
      let toolCall = toolResp.message.tool_calls[0]
      let toolFunc = toolCall.function
      assert toolFunc.name == "get_flight_times"
      let toolFuncArgs = toolCall.function.arguments
      assert toolFuncArgs["departure"].getStr == "NYC"
      assert toolFuncArgs["arrival"].getStr == "LAX"

      let toolResult = getFlightTimes(toolFuncArgs["departure"].getStr, toolFuncArgs["arrival"].getStr)
      messages.add(ChatMessage(
        role: "tool",
        content: option(toolResult)
      ))

      # message history with tool result
      let finalResponse = ollama.chat(ChatReq(
        model: TestModel,
        messages: messages
      ))
      echo "RESULT: " & finalResponse.message.content.get