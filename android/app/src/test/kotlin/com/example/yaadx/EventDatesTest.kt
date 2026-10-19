package com.example.yaadx

import org.junit.Assert.*
import org.junit.Test
import java.time.*

class EventDatesTest {
    private val utc = ZoneId.of("UTC")
    @Test fun advanceCrossesNewYearAndRepeatsWithoutOpeningApp() {
        val first = EventDates.next(2026, 1, 5, 18, 30, true, 10, Instant.parse("2026-12-01T00:00:00Z"), utc)
        assertEquals(Instant.parse("2026-12-26T18:30:00Z"), first)
        val following = EventDates.next(2026, 1, 5, 18, 30, true, 10, first!!.plusSeconds(1), utc)
        assertEquals(Instant.parse("2027-12-26T18:30:00Z"), following)
    }
    @Test fun leapYearAdvanceOffsetsAreRecomputed() {
        assertEquals(Instant.parse("2027-02-23T18:30:00Z"), EventDates.next(2026, 3, 5, 18, 30, true, 10, Instant.parse("2027-01-01T00:00:00Z"), utc))
        assertEquals(Instant.parse("2028-02-24T18:30:00Z"), EventDates.next(2026, 3, 5, 18, 30, true, 10, Instant.parse("2028-01-01T00:00:00Z"), utc))
    }
    @Test fun feb29PolicyAndOneTimeExpiry() {
        assertEquals(28, EventDates.occurrence(2027, 2, 29, 18, 30, utc).dayOfMonth)
        assertEquals(29, EventDates.occurrence(2028, 2, 29, 18, 30, utc).dayOfMonth)
        assertNull(EventDates.next(2026, 1, 1, 0, 0, false, 0, Instant.parse("2026-01-02T00:00:00Z"), utc))
    }
    @Test fun dailyReminderKeepsWallClockTimeAcrossDST() {
        val zone = ZoneId.of("America/New_York")
        val instant = EventDates.next(2026, 3, 10, 9, 0, false, 3, Instant.parse("2026-03-01T00:00:00Z"), zone)!!
        assertEquals(9, instant.atZone(zone).hour)
        assertEquals(7, instant.atZone(zone).dayOfMonth)
    }
}
