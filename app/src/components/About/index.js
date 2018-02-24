import React from "react";
import "./index.css";

const About = ({ heading, content }) => (
  <div className="box about-box">
    <div className="about-title">About</div>
    <div className="about-body">
      This is a tool that lets you create leveraged ETH positions using
      MakerDAO's dai system. You submit ETH, this ETH is then locked in a CDP
      and Dai is drawn. That Dai is then traded for more Eth, which is used to
      fill the CDP even more. Dai is drawn, and the process continues. We call
      the number of these cycles the depth of your position. [We currently
      aren't displaying the tradeoffs of opening deeper positions. This
      demonstration will not make any smartcontract calls.]
    </div>
  </div>
);

export default About;
