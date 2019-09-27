import React from "react";
import LoadingButton from "../LoadingButton";
import Modal from "react-bootstrap/Modal";
import Spinner from "react-bootstrap/Spinner";
import resetLocalTestnet from "../../../helpers/resetLocalTestnet";
import { NotificationManager } from "react-notifications";

class ResetLocalTestnet extends React.Component {
  state = {
    loading: false,
    loadingMsg: ""
  };

  handleResetLocalTestnet = () => {
    const { db, mode } = this.props;
    console.log("Mode: ", mode);
    this.setState({ loading: true });

    resetLocalTestnet(db)
      .on("stdout", data => console.log(`${data}`))
      .on("stderr", data => console.error(`${data}`))
      .run()
      .then(() => {
        NotificationManager.success("Command ran successfully");
      })
      .catch(error => {
        console.error(error);
        NotificationManager.error("An error occurred. Check the logs");
      })
      .finally(() => {
        this.setState({ loading: false });
        console.log(typeof this.props.callBack);
        if (this.props.callBack) this.props.callBack();
      });
  };

  render() {
    const { loading } = this.state;

    return (
      <div>
        <LoadingButton variant="dark" size="lg" block onClick={this.handleResetLocalTestnet} loading={loading}>
          Stop and reset local testnet
        </LoadingButton>
        <Modal show={loading} size="lg" aria-labelledby="contained-modal-title-vcenter" centered backdrop="static">
          <Modal.Body>
            <div className="text-center">
              <p>Resetting network</p>
              <p>
                <small>{this.state.loadingMsg}</small>
              </p>
              <Spinner animation="grow" variant="primary" />
              <Spinner animation="grow" variant="success" />
              <Spinner animation="grow" variant="danger" />
              <Spinner animation="grow" variant="warning" />
              <Spinner animation="grow" variant="info" />
            </div>
          </Modal.Body>
        </Modal>
      </div>
    );
  }
}

export default ResetLocalTestnet;
