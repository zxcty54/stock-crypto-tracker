import unittest
from datetime import datetime
from unittest.mock import patch

import content_generator as generator


class ContentQueueScheduleTests(unittest.TestCase):
    def test_empty_queue_uses_next_two_hour_slot(self):
        now = datetime(2026, 10, 24, 8, 30, tzinfo=generator.IST)
        with patch.object(generator, "NOW", now):
            queue, added = generator.append_to_queue(
                {"queue": []},
                [{"text": "📌 Queue item\nBody", "topic_key": "test"}],
            )

        self.assertEqual(added, ["ai0001"])
        self.assertEqual(queue["queue"][0]["slot"], "B")
        self.assertEqual(queue["queue"][0]["scheduled_ist"], "2026-10-24 10:00")

    def test_queue_continues_on_next_day_after_last_slot(self):
        now = datetime(2026, 10, 24, 18, 0, tzinfo=generator.IST)
        queue = {"queue": [{
            "id": "ai0007",
            "slot": "G",
            "scheduled_ist": "2026-10-24 20:00",
        }]}
        with patch.object(generator, "NOW", now):
            queue, added = generator.append_to_queue(queue, [
                {"text": "📌 First item\nBody", "topic_key": "one"},
                {"text": "📌 Second item\nBody", "topic_key": "two"},
            ])

        self.assertEqual(added, ["ai0008", "ai0009"])
        self.assertEqual(queue["queue"][1]["scheduled_ist"], "2026-10-25 08:00")
        self.assertEqual(queue["queue"][2]["scheduled_ist"], "2026-10-25 10:00")


if __name__ == "__main__":
    unittest.main()
