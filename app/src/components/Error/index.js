import React from "react";
import "./index.css";

const Error = ({ heading, content }) => (
  <div className="error">
    <h3>{heading}</h3>
    <p>{content}</p>
  </div>
);

export default Error;
