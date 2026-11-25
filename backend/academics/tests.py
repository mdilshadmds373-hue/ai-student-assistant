from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()


class IsolationTests(APITestCase):
    def setUp(self):
        self.a = User.objects.create_user("a@x.com", "a@x.com", "pw12345678")
        self.b = User.objects.create_user("b@x.com", "b@x.com", "pw12345678")

    def test_user_b_cannot_touch_user_a_data(self):
        self.client.force_authenticate(self.a)
        r = self.client.post("/api/subjects/", {"name": "Python"})
        self.assertEqual(r.status_code, 201)
        sid = r.data["id"]

        self.client.force_authenticate(self.b)
        self.assertEqual(self.client.get("/api/subjects/").data, [])
        self.assertEqual(self.client.get(f"/api/subjects/{sid}/").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/subjects/{sid}/").status_code, 404)
        r = self.client.post("/api/tasks/", {"title": "x", "subject": sid})
        self.assertEqual(r.status_code, 400)

    def test_login_required(self):
        self.assertEqual(self.client.get("/api/subjects/").status_code, 401)
