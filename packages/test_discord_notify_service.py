import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("discord-notify-service.py")
SPEC = importlib.util.spec_from_file_location("discord_notify_service", MODULE_PATH)
assert SPEC and SPEC.loader
SERVICE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVICE)


class DiscordNotifyServiceTests(unittest.TestCase):
    def test_configured_channels_exposes_names_only(self) -> None:
        channels = SERVICE.configured_channels(
            {
                "DISCORD_CHANNEL_DEFAULT_WEBHOOK_URL": "https://example.test/secret",
                "DISCORD_CHANNEL_BUILD_ALERTS_WEBHOOK_URL": "https://example.test/other",
                "IGNORED": "value",
            }
        )
        self.assertEqual(set(channels), {"default", "build-alerts"})

    def test_payload_disables_mentions(self) -> None:
        payload = SERVICE.make_payload(
            {
                "title": "Finished",
                "body": "@everyone deployment completed",
                "status": "success",
                "source": "release-workflow",
            },
            "default",
        )
        self.assertEqual(payload["allowed_mentions"], {"parse": []})
        self.assertEqual(payload["embeds"][0]["color"], SERVICE.STATUS_COLORS["success"])

    def test_payload_rejects_unknown_status(self) -> None:
        with self.assertRaisesRegex(ValueError, "status must be one of"):
            SERVICE.make_payload({"title": "Nope", "status": "critical"}, "default")

    def test_openapi_has_expected_tools_and_bearer_auth(self) -> None:
        document = SERVICE.openapi_document()
        self.assertEqual(document["paths"]["/channels"]["get"]["operationId"], "listChannels")
        self.assertEqual(document["paths"]["/messages"]["post"]["operationId"], "sendNotification")
        self.assertEqual(document["security"], [{"bearerAuth": []}])


if __name__ == "__main__":
    unittest.main()
