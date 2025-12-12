using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Options;

namespace ZavaStorefront.Services;

public class AzureOpenAIChatService : IChatService
{
    private readonly HttpClient _httpClient;
    private readonly AzureOpenAIOptions _options;

    public AzureOpenAIChatService(HttpClient httpClient, IOptions<AzureOpenAIOptions> options)
    {
        _httpClient = httpClient;
        _options = options.Value;
    }

    public async Task<string> SendMessageAsync(string userMessage, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.Endpoint))
        {
            throw new InvalidOperationException("AzureOpenAI:Endpoint is not configured.");
        }

        var endpoint = _options.Endpoint!.TrimEnd('/');
        var deployment = string.IsNullOrWhiteSpace(_options.DeploymentName) ? "gpt-4.1-deployment" : _options.DeploymentName;
        var apiVersion = string.IsNullOrWhiteSpace(_options.ApiVersion) ? "2024-10-21" : _options.ApiVersion;

        var requestUri = $"{endpoint}/openai/deployments/{Uri.EscapeDataString(deployment)}/chat/completions?api-version={Uri.EscapeDataString(apiVersion)}";

        using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);

        if (!string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            request.Headers.Add("api-key", _options.ApiKey);
        }
        else
        {
            var credential = new DefaultAzureCredential();
            var token = await credential.GetTokenAsync(
                new TokenRequestContext(["https://cognitiveservices.azure.com/.default"]),
                cancellationToken);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        }

        var payload = new
        {
            messages = new object[]
            {
                new { role = "user", content = userMessage }
            },
            temperature = 0.2,
            max_tokens = 512
        };

        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        var json = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Azure OpenAI request failed: {(int)response.StatusCode} {response.ReasonPhrase}. Body: {json}");
        }

        return ExtractAssistantMessage(json) ?? string.Empty;
    }

    private static string? ExtractAssistantMessage(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);

            if (!doc.RootElement.TryGetProperty("choices", out var choices) || choices.ValueKind != JsonValueKind.Array)
            {
                return null;
            }

            foreach (var choice in choices.EnumerateArray())
            {
                if (choice.TryGetProperty("message", out var message)
                    && message.TryGetProperty("content", out var content)
                    && content.ValueKind == JsonValueKind.String)
                {
                    return content.GetString();
                }
            }

            return null;
        }
        catch
        {
            return null;
        }
    }
}
