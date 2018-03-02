import React, { PureComponent } from 'react'
import web3, { initWeb3 } from '../../utils/web3'
import { fetchOracleCurrent, twoDecimalFloat } from '../../utils/misc-helpers'

import './index.css'

class Leverager extends PureComponent {
  state = {
    priceFloor: '',
    AmtETH: '',
    ETHUSD: null,
    collatRatio: null,
    leverage: null,
    depth: 3,
    error: false
  }
  componentWillMount = () => {
    fetchOracleCurrent()
      .then(currPrice => {
        this.setState({ ETHUSD: currPrice })
      })
      .catch(() => {
        this.setState({ error: 'Problem fetching current ETH price' })
      })
  }
  componentDidMount = () => {
    initWeb3(web3)
    if (!web3.currentProvider.isMetaMask === true) {
      this.setState({ error: 'Please install metamask' })
    }
  }
  handleFloorChange = ({ target: { value = '' } }) => {
    const priceFloor = parseFloat(value) || null
    if (priceFloor > this.state.ETHUSD && !this.state.error) {
      this.setState({
        error: `Price floor must be below current ETH price ($${this.state.ETHUSD})`
      })
      this.setState({ priceFloor })
    } else {
      !!this.state.error && this.setState({ error: false })
      this.calculateRatioAndLeverage(priceFloor)
      this.setState({ priceFloor })
    }
  }
  handleETHChange = ({ target: { value = '' } }) => {
    const AmtETH = parseFloat(value) || null
    this.setState({ AmtETH })
  }
  calculateRatioAndLeverage = priceFloor => {
    const collatRatio = this.calculateCollatRatio(priceFloor)
    const leverage = this.calculateLeverage(collatRatio)
    this.setState({ collatRatio, leverage })
  }
  calculateCollatRatio = priceFloor => {
    const CollatRatio = this.state.ETHUSD * 1.5 / priceFloor
    return twoDecimalFloat(CollatRatio)
  }
  setDepth = ({ target: { value = '' } }) => {
    const depth = parseInt(value, 10) || null
    this.setState({ depth }, () => {
      this.calculateRatioAndLeverage(this.state.priceFloor)
    })
  }
  calculateLeverage = collatRatio => {
    const steps = parseInt(this.state.depth, 10) || 0
    let leverage = 1,
      currStep = 1
    for (let i = 0; i < steps; i++) {
      currStep = currStep * 1 / collatRatio
      leverage += currStep
    }
    return twoDecimalFloat(leverage)
  }
  createPosition = () => {
    const leveragerProxy = new web3.eth.Contract([], '0x59d7371a3026eaa3242f19b8b7ead9173a236c61')
    // leveragerProxy.methods
    //   .leverage(x, x)
    //   .estimateGas({}, function(error, gasAmount) {
    //     if (gasAmount == 5000000) console.log("Method ran out of gas");
    //   });
    // leveragerProxy.methods
    //   .leverage(x, x)
    //   .send({ from: "xxx" }, function(
    //     error,
    //     transactionHash
    //    )
  }
  handleKeyDownDepth = ({ key }) => {
    if (key === 'ArrowDown') {
      this.setState(
        prevState => ({ depth: prevState.depth - 1 }),
        () => {
          this.calculateRatioAndLeverage(this.state.priceFloor)
        }
      )
    }
    if (key === 'ArrowUp') {
      this.setState(
        prevState => ({ depth: prevState.depth + 1 }),
        () => {
          this.calculateRatioAndLeverage(this.state.priceFloor)
        }
      )
    }
  }
  handleKeyDownFloor = ({ key }) => {
    if (key === 'ArrowDown') {
      this.setState(
        prevState => ({ priceFloor: prevState.priceFloor - 1 }),
        () => {
          this.calculateRatioAndLeverage(this.state.priceFloor)
        }
      )
    }
    if (key === 'ArrowUp') {
      this.setState(
        prevState => ({ priceFloor: prevState.priceFloor + 1 }),
        () => {
          this.calculateRatioAndLeverage(this.state.priceFloor)
        }
      )
    }
  }
  render () {
    return (
      <div className='box leverager-box'>
        <div className='leverager-box-header'>
          <div className='leverager-inputs'>
            <div className='input-container'>
              <div className='input-label'>Depth:</div>
              <input
                className='left-padded-input'
                value={this.state.depth}
                type='text'
                placeholder='3'
                onChange={this.setDepth}
                onKeyDown={this.handleKeyDownDepth}
              />
            </div>
            <div className='input-container'>
              <div className='input-label'>Price Floor:</div>
              <span style={{ opacity: this.state.priceFloor ? '1' : '0.4' }} className='dollar-sign'>
                $
              </span>
              <input
                value={this.state.priceFloor}
                type='text'
                placeholder='600'
                onChange={this.handleFloorChange}
                onKeyDown={this.handleKeyDownFloor}
              />
            </div>{' '}
            <div className='input-container'>
              <div className='input-label'>Amount of ETH:</div>
              <input
                className='left-padded-input'
                value={this.state.AmtETH}
                type='text'
                placeholder='10'
                onChange={this.handleETHChange}
              />
            </div>
          </div>
          <div onClick={this.createPosition} style={{ marginTop: '1.5rem', textAlign: 'center' }}>
            Create Leveraged Position
          </div>
        </div>

        {this.state.error ? (
          <div className='leverager-error'>{this.state.error}</div>
        ) : (
          !!this.state.ETHUSD && (
            <div className='leverager-info'>
              <div className='stat'>
                <div className='stat-item'>${this.state.ETHUSD}</div>
                <div className='stat-title'>Current Price of ETH</div>
              </div>
              <div className='stat'>
                <div className='stat-item'>{`${this.state.leverage ? this.state.leverage : '1'}x`}</div>
                <div className='stat-title'>Leverage</div>
              </div>
            </div>
          )
        )}
      </div>
    )
  }
}

export default Leverager
