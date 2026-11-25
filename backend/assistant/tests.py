from unittest.mock import patch

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()


class ChatTests(APITestCase):
    def setUp(self):
        self.a = User.objects.create_user("a@x.com", "a@x.com", "pw12345678")
        self.b = User.objects.create_user("b@x.com", "b@x.com", "pw12345678")

    @patch("assistant.views.call_gemini", return_value="Jawab")
    def test_chat_and_isolation(self, _mock):
        self.client.force_authenticate(self.a)
        cid = self.client.post("/api/conversations/", {}).data["id"]
        r = self.client.post(f"/api/conversations/{cid}/send/", {"content": "Hello"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(self.client.get(f"/api/conversations/{cid}/").data["messages"]), 2)

        self.client.force_authenticate(self.b)
        self.assertEqual(self.client.get("/api/conversations/").data, [])
        self.assertEqual(self.client.get(f"/api/conversations/{cid}/").status_code, 404)
        self.assertEqual(self.client.post(f"/api/conversations/{cid}/send/", {"content": "x"}).status_code, 404)

    def test_login_required(self):
        self.assertEqual(self.client.get("/api/conversations/").status_code, 401)
