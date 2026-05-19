importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCc3hejLcJOx9OdtU_aSK7RN8nh6b6U7RM",
  appId: "1:88644784996:web:fa615728c2de01fc07a071",
  messagingSenderId: "88644784996",
  projectId: "student-companion-d53ec",
});

const messaging = firebase.messaging();
