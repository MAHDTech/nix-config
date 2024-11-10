// Returns the current date in a formatted string
// that is suitable for display in the bar.
export const DataCurrentTime = Variable("", {
  poll: [1000, 'date "+%H:%M:%S %b %e."'],
});

// Returns the current date in a formatted string
// that is suitable for display in the bar.
export const DataCurrentData = Variable("", {
  poll: [
    1000,
    function () {
      return Date().toString();
    },
  ],
});
