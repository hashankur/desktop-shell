import { createState, onCleanup } from "ags";
import GLib from "gi://GLib";

// Create a reactive current time that updates every minute
const [currentTime, setCurrentTime] = createState(
  Math.floor(Date.now() / 1000),
);

// Update current time every minute
const timeInterval = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60000, () => {
  setCurrentTime(Math.floor(Date.now() / 1000));
  return true; // Continue the timeout
});

onCleanup(() => {
  GLib.source_remove(timeInterval);
});

// Time constants
const SECOND = 1;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

/**
 * Format a timestamp using GLib.DateTime
 */
export const formatTime = (timestamp: number, format = "%a %b %d %I:%M %p"): string =>
  GLib.DateTime.new_from_unix_local(timestamp).format(format) || "";

/**
 * Get relative time string from a timestamp
 */
export const getRelativeTime = (
  timestampInSeconds: number,
  nowInSeconds: number,
): string => {
  const diff = nowInSeconds - timestampInSeconds;

  if (diff < MINUTE) {
    return "Just now";
  }
  if (diff < HOUR) {
    const minutes = Math.floor(diff / MINUTE);
    return `${minutes} minute${minutes > 1 ? "s" : ""} ago`;
  }
  if (diff < DAY) {
    const hours = Math.floor(diff / HOUR);
    return `${hours} hour${hours > 1 ? "s" : ""} ago`;
  }
  if (diff < WEEK) {
    const days = Math.floor(diff / DAY);
    return `${days} day${days > 1 ? "s" : ""} ago`;
  }
  // For older timestamps, display the exact date and time
  return formatTime(timestampInSeconds);
};

/**
 * Get reactive relative time for a given timestamp
 * This will automatically update as time passes
 */
export const useRelativeTime = (timestamp: number) => {
  return currentTime((now) => getRelativeTime(timestamp, now));
};

/**
 * Get tooltip text with full timestamp
 */
export const getTimeTooltip = (timestamp: number): string => {
  return formatTime(timestamp);
};

/**
 * Check if a timestamp is from today
 */
export const isToday = (timestamp: number): boolean => {
  const now = GLib.DateTime.new_now_local();
  const date = GLib.DateTime.new_from_unix_local(timestamp);

  return (
    now.get_year() === date.get_year() &&
    now.get_month() === date.get_month() &&
    now.get_day_of_month() === date.get_day_of_month()
  );
};

/**
 * Check if a timestamp is from yesterday
 */
export const isYesterday = (timestamp: number): boolean => {
  const now = GLib.DateTime.new_now_local();
  const yesterday = now.add_days(-1);
  const date = GLib.DateTime.new_from_unix_local(timestamp);

  return (
    yesterday.get_year() === date.get_year() &&
    yesterday.get_month() === date.get_month() &&
    yesterday.get_day_of_month() === date.get_day_of_month()
  );
};

/**
 * Get current timestamp in seconds
 */
export const getCurrentTimestamp = (): number => {
  return Math.floor(Date.now() / 1000);
};

// Export the reactive time state for advanced usage
export { currentTime };
