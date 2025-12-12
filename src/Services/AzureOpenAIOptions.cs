namespace ZavaStorefront.Services;

public class AzureOpenAIOptions
{
    public const string SectionName = "AzureOpenAI";

    public string? Endpoint { get; set; }

    public string DeploymentName { get; set; } = "gpt-4.1-deployment";

    public string ApiVersion { get; set; } = "2024-10-21";

    public string? ApiKey { get; set; }
}
