using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers;

public class ChatController : Controller
{
    private const string ChatHistorySessionKey = "ChatHistoryText";
    private readonly ILogger<ChatController> _logger;
    private readonly IChatService _chatService;

    public ChatController(ILogger<ChatController> logger, IChatService chatService)
    {
        _logger = logger;
        _chatService = chatService;
    }

    [HttpGet]
    public IActionResult Index()
    {
        var history = HttpContext.Session.GetString(ChatHistorySessionKey) ?? string.Empty;
        return View(new ChatPageViewModel { HistoryText = history });
    }

    [HttpPost]
    [EnableRateLimiting("chat")]
    public async Task<IActionResult> SendMessage([FromBody] ChatRequest request, CancellationToken cancellationToken)
    {
        var message = (request.Message ?? string.Empty).Trim();

        if (string.IsNullOrWhiteSpace(message))
        {
            return BadRequest(new ChatResponse { Error = "Message is required." });
        }

        if (message.Length > 2000)
        {
            return BadRequest(new ChatResponse { Error = "Message is too long (max 2000 characters)." });
        }

        try
        {
            _logger.LogInformation("Chat message received ({Length} chars)", message.Length);

            var reply = await _chatService.SendMessageAsync(message, cancellationToken);

            var history = HttpContext.Session.GetString(ChatHistorySessionKey) ?? string.Empty;
            history = AppendLine(history, $"You: {message}");
            history = AppendLine(history, $"AI: {reply}");
            history = AppendLine(history, string.Empty);
            HttpContext.Session.SetString(ChatHistorySessionKey, history);

            return Ok(new ChatResponse { Reply = reply });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Chat request failed");
            return StatusCode(StatusCodes.Status502BadGateway, new ChatResponse { Error = "Chat request failed. Check configuration and try again." });
        }
    }

    private static string AppendLine(string existing, string line)
    {
        if (string.IsNullOrEmpty(existing))
        {
            return line;
        }

        return existing + Environment.NewLine + line;
    }
}
