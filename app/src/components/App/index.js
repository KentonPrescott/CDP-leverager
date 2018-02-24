import React from "react";

import About from "../About";
import Logo from "../Logo";
import Leverager from "../Leverager";

import "./index.css";

const App = ({ heading, content }) => (
  <div className="App">
    <Logo />
    <About />
    <Leverager />
  </div>
);

export default App;
