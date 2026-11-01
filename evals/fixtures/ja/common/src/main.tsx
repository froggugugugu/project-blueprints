import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

export function App() {
  return <main>備品管理</main>;
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
