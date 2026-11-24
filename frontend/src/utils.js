// Server ke error response ko saaf text mein badalta hai
export function errorText(err) {
  const data = err.response?.data;
  if (!data) return "Server se connect nahi ho saka. Backend chal raha hai?";
  if (data.detail) return data.detail;
  return Object.values(data).flat().join(" ");
}
