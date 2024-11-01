// Returns the current time.
export const DataTime = Variable("", {
  poll: [
    1000,
    function () {
      return Date().toString();
    },
  ],
});
