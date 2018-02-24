import React from "react";
import ReactDOM from "react-dom";

import App from "./components/App";
import { isMobile } from "./utils/misc-helpers";
import Error from "./components/Error";

import "./index.css";

let appComponent;
if (isMobile()) {
  appComponent = (
    <Error
      heading="Sorry, right now this is a desktop-only experience."
      content="We're in the early stages, so mobile support is still in the works"
    />
  );
} else {
  appComponent = <App />;
}

ReactDOM.render(appComponent, document.getElementById("root"));
